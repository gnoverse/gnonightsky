package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"gopkg.in/ini.v1"
)

type config struct {
	Gno struct {
		RealmPath string `ini:"realm_path"`
		Remote    string `ini:"remote"`
		ChainID   string `ini:"chain_id"`
		Wallet    string `ini:"wallet"`
		Interval  int    `ini:"interval_seconds"`
	} `ini:"gno"`
	Imgur struct {
		ClientID  string `ini:"client_id"`
		ImageFile string `ini:"image_file"`
	} `ini:"imgur"`
	Telescope struct {
		BinCapture string `ini:"bin_capture"`
		BinStop    string `ini:"bin_stop"`
	} `ini:"telescope"`
}

func loadConfig(path string) config {
	cfg := config{}
	if err := ini.MapTo(&cfg, path); err != nil {
		log.Fatalf("Cannot load config file %s: %v", path, err)
	}
	if cfg.Gno.RealmPath == "" || cfg.Gno.Remote == "" || cfg.Gno.Wallet == "" {
		log.Fatal("config.ini must define realm_path, remote, and wallet under [gno]")
	}
	if cfg.Telescope.BinCapture == "" || cfg.Telescope.BinStop == "" {
		log.Fatal("config.ini must define bin_capture and bin_stop under [telescope]")
	}
	if cfg.Gno.Interval <= 0 {
		cfg.Gno.Interval = 10
	}
	return cfg
}

// gnokeyQuery runs gnokey query vm/qrender and returns the content inside the ``` block
func gnokeyQuery(cfg config, path string) (string, error) {
	sh := fmt.Sprintf(
		"gnokey query vm/qrender -remote %s -data '%s:%s' | awk '/```/{f=!f; next} f'",
		cfg.Gno.Remote, cfg.Gno.RealmPath, path,
	)
	out, err := exec.Command("sh", "-c", sh).Output()
	if err != nil {
		return "", fmt.Errorf("query %s: %w", path, err)
	}
	return strings.TrimSpace(string(out)), nil
}

// gnokeyCall runs gnokey maketx call for the given function and args
func gnokeyCall(cfg config, fn string, args ...string) error {
	argFlags := ""
	for _, a := range args {
		argFlags += fmt.Sprintf(" -args %q", a)
	}
	sh := fmt.Sprintf(
		`echo "" | gnokey maketx call -pkgpath "%s" -func "%s"%s -gas-fee 1000000ugnot -gas-wanted 10000000 -send "" -broadcast -chainid "%s" -insecure-password-stdin=true -remote "%s" %s`,
		cfg.Gno.RealmPath, fn, argFlags, cfg.Gno.ChainID, cfg.Gno.Remote, cfg.Gno.Wallet,
	)
	out, err := exec.Command("sh", "-c", sh).CombinedOutput()
	if err != nil {
		return fmt.Errorf("call %s: %w\n%s", fn, err, out)
	}
	log.Printf("✅ %s: OK", fn)
	return nil
}

// status holds the parsed :status page values
type status struct {
	commands int
	state    string
}

func getStatus(cfg config) (status, error) {
	raw, err := gnokeyQuery(cfg, "status")
	if err != nil {
		return status{}, err
	}

	s := status{}
	for _, line := range strings.Split(raw, "\n") {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		switch strings.TrimSpace(parts[0]) {
		case "commands":
			s.commands, _ = strconv.Atoi(strings.TrimSpace(parts[1]))
		case "status":
			s.state = strings.TrimSpace(parts[1])
		}
	}
	return s, nil
}

// telescopeCommand holds the parsed :commandData page values
type telescopeCommand struct {
	commandType string
	ra          float64
	dec         float64
	exposure    int
	requester   string
}

func getCommandData(cfg config) (telescopeCommand, error) {
	raw, err := gnokeyQuery(cfg, "commandData")
	if err != nil {
		return telescopeCommand{}, err
	}
	if raw == "no_commands" {
		return telescopeCommand{}, fmt.Errorf("no commands")
	}

	cmd := telescopeCommand{}
	for _, line := range strings.Split(raw, "\n") {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		switch key {
		case "type":
			cmd.commandType = val
		case "ra":
			cmd.ra, _ = strconv.ParseFloat(val, 64)
		case "dec":
			cmd.dec, _ = strconv.ParseFloat(val, 64)
		case "exposure":
			cmd.exposure, _ = strconv.Atoi(val)
		case "requester":
			cmd.requester = val
		}
	}
	return cmd, nil
}

func runCommand(cfg config, cmd telescopeCommand) {
	switch cmd.commandType {
	case "capture":
		if err := gnokeyCall(cfg, "UpdateStatus", "busy"); err != nil {
			log.Printf("⚠️  UpdateStatus busy: %v", err)
			return
		}
		imageURL, err := telescopeCapture(cfg, cmd.ra, cmd.dec, cmd.exposure)
		if err != nil {
			return
		}
		if err := gnokeyCall(cfg, "GetNextCommand"); err != nil {
			log.Printf("⚠️  GetNextCommand: %v", err)
			return
		}
		if err := gnokeyCall(cfg, "RecordCapture",
			imageURL,
			fmt.Sprintf("%.8f", cmd.ra),
			fmt.Sprintf("%.8f", cmd.dec),
			strconv.Itoa(cmd.exposure),
			cmd.requester,
		); err != nil {
			log.Printf("⚠️  RecordCapture: %v", err)
			return
		}
		if err := gnokeyCall(cfg, "UpdateStatus", "online"); err != nil {
			log.Printf("⚠️  UpdateStatus online: %v", err)
		}

	case "stop":
		if err := telescopeStop(cfg); err != nil {
			return
		}
		if err := gnokeyCall(cfg, "GetNextCommand"); err != nil {
			log.Printf("⚠️  GetNextCommand: %v", err)
			return
		}
		if err := gnokeyCall(cfg, "UpdateStatus", "online"); err != nil {
			log.Printf("⚠️  UpdateStatus online: %v", err)
		}

	default:
		log.Printf("❌ Unknown command type: %s", cmd.commandType)
	}
}

func main() {
	cfg := loadConfig("config.ini")

	log.Println("🔭 Telescope Controller starting...")
	log.Printf("Realm:    %s", cfg.Gno.RealmPath)
	log.Printf("Remote:   %s", cfg.Gno.Remote)
	log.Printf("Wallet:   %s", cfg.Gno.Wallet)
	log.Printf("Interval: %ds", cfg.Gno.Interval)

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	ticker := time.NewTicker(time.Duration(cfg.Gno.Interval) * time.Second)
	defer ticker.Stop()

	// run once immediately, then on each tick
	poll(cfg)
	for {
		select {
		case <-ticker.C:
			poll(cfg)
		case <-stop:
			log.Println("\n👋 Shutting down...")
			return
		}
	}
}

func poll(cfg config) {
	s, err := getStatus(cfg)
	if err != nil {
		log.Printf("⚠️  getStatus: %v", err)
		return
	}
	log.Printf("📡 status=%s  commands=%d", s.state, s.commands)

	if s.commands == 0 {
		return
	}

	cmd, err := getCommandData(cfg)
	if err != nil {
		log.Printf("⚠️  getCommandData: %v", err)
		return
	}

	log.Printf("🎯 Executing: %s  RA=%.8f  Dec=%.8f  Exposure=%ds  Requester=%s",
		cmd.commandType, cmd.ra, cmd.dec, cmd.exposure, cmd.requester)

	runCommand(cfg, cmd)
}

// ---- Telescope hardware functions (implement these) ----

func telescopeCapture(cfg config, ra, dec float64, exposureSec int) (string, error) {
	parts := strings.Fields(cfg.Telescope.BinCapture)
	parts = append(parts,
		fmt.Sprintf("%.8f", ra),
		fmt.Sprintf("%.8f", dec),
		strconv.Itoa(exposureSec),
	)
	log.Printf("  → CAPTURE  RA=%.8fh  Dec=%.8f°  exposure=%ds", ra, dec, exposureSec)
	cmd := exec.Command(parts[0], parts[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Printf("  ⚠️  capture command failed: %v", err)
		return "", err
	}

	url, err := uploadToImgur(cfg)
	if err != nil {
		log.Printf("  ⚠️  Imgur upload failed: %v", err)
		return "", err
	}
	log.Printf("  📸 Uploaded: %s", url)
	return url, nil
}

func telescopeStop(cfg config) error {
	parts := strings.Fields(cfg.Telescope.BinStop)
	log.Printf("  → STOP all telescope operations")
	cmd := exec.Command(parts[0], parts[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Printf("  ⚠️  stop command failed: %v", err)
		return err
	}
	return nil
}

// ---- Imgur upload ----

func uploadToImgur(cfg config) (string, error) {
	f, err := os.Open(cfg.Imgur.ImageFile)
	if err != nil {
		return "", fmt.Errorf("open %s: %w", cfg.Imgur.ImageFile, err)
	}
	defer f.Close()

	var body bytes.Buffer
	w := multipart.NewWriter(&body)

	part, err := w.CreateFormFile("image", filepath.Base(cfg.Imgur.ImageFile))
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(part, f); err != nil {
		return "", err
	}
	w.Close()

	req, err := http.NewRequest("POST", "https://api.imgur.com/3/image", &body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Client-ID "+cfg.Imgur.ClientID)
	req.Header.Set("Content-Type", w.FormDataContentType())

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	rawBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("imgur: read response: %w", err)
	}

	var result struct {
		Data struct {
			Link  string `json:"link"`
			Error string `json:"error"`
		} `json:"data"`
		Success bool `json:"success"`
		Status  int  `json:"status"`
	}
	if err := json.Unmarshal(rawBody, &result); err != nil {
		return "", fmt.Errorf("imgur: decode response (status %d): %w\nbody: %s", resp.StatusCode, err, rawBody)
	}
	if !result.Success {
		return "", fmt.Errorf("imgur: upload failed (HTTP %d, API %d): %s", resp.StatusCode, result.Status, result.Data.Error)
	}
	return result.Data.Link, nil
}
