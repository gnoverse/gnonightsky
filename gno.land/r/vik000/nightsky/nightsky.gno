package nightsky

import (
	"chain/runtime"
	"time"

	"gno.land/p/moul/md"
	"gno.land/p/nt/ufmt"
	"gno.land/p/vik000/nightsky"
	"gno.land/r/leon/hor"
	"gno.land/r/sys/users"
)

var (
	// Registry of all telescopes in the network, keyed by realm pkgPath
	telescopes = make(map[string]nightsky.TelescopeConfig)

	// Recent captures from all telescopes
	recentCaptures = []nightsky.CaptureResult{}

	// Maximum captures to keep in recent list
	maxRecentCaptures = 50
)

func init() {
	hor.Register(cross, "NightSky", "decentralized telescope network for stargazing 🔭")
}

// Register registers a telescope realm in the NightSky network.
// Call from your realm's init() function:
//
//	nightsky.Register(cross, config)
func Register(cur realm, cfg nightsky.TelescopeConfig) {
	submission := runtime.PreviousRealm()
	pkgPath := submission.PkgPath()

	if submission.IsUser() {
		panic("Register must be called from realm code, not a user transaction")
	}

	if _, exists := telescopes[pkgPath]; exists {
		return // already registered, silently ignore duplicate
	}

	if cfg.Name == "" || cfg.Model == "" || cfg.Owner == "" {
		panic("telescope name, model, and owner cannot be empty")
	}

	cfg.RealmPath = pkgPath

	telescopes[pkgPath] = cfg
}

// UpdateTelescopeStatus allows a registered telescope realm to update its status in the registry.
// Call from your realm: nightsky.UpdateTelescopeStatus(cross, "online")
func UpdateTelescopeStatus(cur realm, status string) {
	submission := runtime.PreviousRealm()
	pkgPath := submission.PkgPath()

	if submission.IsUser() {
		panic("must be called from realm code")
	}

	config, exists := telescopes[pkgPath]
	if !exists {
		panic("telescope not registered")
	}

	config.UpdateStatus(status)
	telescopes[pkgPath] = config
}

// SubmitCapture allows a registered telescope realm to add a capture to the network feed.
// Call from your realm: nightsky.SubmitCapture(cross, imageURL, ra, dec, exposure, capturedBy)
func SubmitCapture(cur realm, imageURL string, targetRA, targetDec float64, exposure int, capturedBy string) {
	submission := runtime.PreviousRealm()
	pkgPath := submission.PkgPath()

	if submission.IsUser() {
		panic("must be called from realm code")
	}

	config, exists := telescopes[pkgPath]
	if !exists {
		panic("telescope not registered")
	}

	if imageURL == "" {
		panic("image URL cannot be empty")
	}

	capture := nightsky.CaptureResult{
		ImageURL:    imageURL,
		TargetRA:    targetRA,
		TargetDec:   targetDec,
		Exposure:    exposure,
		CapturedBy:  capturedBy,
		CapturedAt:  time.Now(),
		TelescopeID: config.Name,
	}

	recentCaptures = append([]nightsky.CaptureResult{capture}, recentCaptures...)
	if len(recentCaptures) > maxRecentCaptures {
		recentCaptures = recentCaptures[:maxRecentCaptures]
	}
}

// UnregisterTelescope removes a telescope realm from the network.
// Call from your realm: nightsky.UnregisterTelescope(cross)
func UnregisterTelescope(cur realm) {
	submission := runtime.PreviousRealm()
	pkgPath := submission.PkgPath()

	if submission.IsUser() {
		panic("must be called from realm code")
	}

	if _, exists := telescopes[pkgPath]; !exists {
		panic("telescope not registered")
	}

	delete(telescopes, pkgPath)
}

// GetTelescopeCount returns the number of registered telescopes
func GetTelescopeCount() int {
	return len(telescopes)
}

// GetOnlineTelescopeCount returns the number of online telescopes
func GetOnlineTelescopeCount() int {
	count := 0
	for _, config := range telescopes {
		if config.Status == "online" {
			count++
		}
	}
	return count
}

func usernameOrAddressLink(addr string) string {
	user := users.ResolveAddress(address(addr))
	if user != nil {
		return user.RenderLink("")
	}
	return addr
}

func Render(path string) string {
	if path == "telescopes" {
		return renderTelescopeList()
	}

	if path == "captures" {
		return renderRecentCaptures()
	}

	if path == "map" {
		return renderTelescopeMap()
	}

	return renderMainPage()
}

func renderMainPage() string {
	out := ""
	out += md.H1("Gno NightSky 🔭")
	out += "Decentralized telescope network for stargazing\n\n"
	out += "Connect your smart telescope to the Gno.land blockchain and share access to the stars!\n\n"

	out += md.H2("Network Status")
	totalTelescopes := GetTelescopeCount()
	onlineTelescopes := GetOnlineTelescopeCount()
	out += ufmt.Sprintf("🔭 Total Telescopes: %d\n\n", totalTelescopes)
	out += ufmt.Sprintf("🟢 Online: %d\n\n", onlineTelescopes)
	out += ufmt.Sprintf("🔴 Offline: %d\n\n", totalTelescopes-onlineTelescopes)

	out += md.H2("Quick Links")
	out += md.Link("View All Telescopes", "/r/vik000/nightsky:telescopes") + "\n\n"
	out += md.Link("Recent Captures", "/r/vik000/nightsky:captures") + "\n\n"
	out += md.Link("Telescope Map", "/r/vik000/nightsky:map") + "\n\n"

	if len(recentCaptures) > 0 {
		latest := recentCaptures[0]
		out += md.H2("Latest Capture")
		out += "![Latest capture](" + latest.ImageURL + ")\n\n"
		out += ufmt.Sprintf("_RA %.8fh · Dec %.8f° · %ds · %s_\n\n",
			latest.TargetRA, latest.TargetDec, latest.Exposure, latest.TelescopeID)
	}

	out += md.HorizontalRule()

	out += md.H2("How to Register Your Telescope")
	out += "Deploy your own telescope realm using the `/p/vik000/nightsky` package,\n"
	out += "then call `nightsky.Register(cross, ...)` from your `init()` function.\n\n"
	out += "You can clone " + md.Link("my telescope realm", "/r/vik000/telescope") + " as a starting point.\n\n"

	out += md.H2("About")
	out += "NightSky enables telescope owners to share access to their equipment through a decentralized network.\n\n"
	out += "Also take a look at " + md.Link("PiaGno", "https://github.com/gnoverse/piagno") + " 🎹\n\n"

	out += "If you enjoy NightSky, please upvote in "
	out += md.Link("the Hall of Realms", "/r/leon/hor:hall?sort=creation") + "!\n\n"

	return out
}

func renderTelescopeList() string {
	out := ""
	out += md.H1("NightSky - Telescope Network")

	if len(telescopes) == 0 {
		out += "\nNo telescopes registered yet.\n\n"
		out += md.Link("← Back to main page", "/r/vik000/nightsky") + "\n\n"
		return out
	}

	out += ufmt.Sprintf("\nTotal: %d telescopes\n\n", len(telescopes))

	for _, config := range telescopes {
		statusIcon := "🔴"
		switch config.Status {
		case "online":
			statusIcon = "🟢"
		case "busy":
			statusIcon = "🟡"
		case "error":
			statusIcon = "🔴"
		}

		out += md.H3(statusIcon + " " + config.Name)
		out += ufmt.Sprintf("**Model:** %s\n\n", config.Model)
		out += ufmt.Sprintf("**Owner:** %s\n\n", usernameOrAddressLink(config.Owner))
		out += ufmt.Sprintf("**Location:** %.4f°, %.4f°\n\n", config.Latitude, config.Longitude)
		out += ufmt.Sprintf("**Status:** %s\n\n", config.Status)
		out += ufmt.Sprintf("**Realm:** %s\n\n", md.Link("Visit", config.RealmPath))
		out += md.HorizontalRule()
	}

	out += md.Link("← Back to main page", "/r/vik000/nightsky") + "\n\n"

	return out
}

func renderRecentCaptures() string {
	out := ""
	out += md.H1("NightSky - Recent Captures")

	if len(recentCaptures) == 0 {
		out += "\nNo captures yet.\n\n"
		out += md.Link("← Back to main page", "/r/vik000/nightsky") + "\n\n"
		return out
	}

	out += ufmt.Sprintf("\nShowing %d most recent captures\n\n", len(recentCaptures))

	for i, capture := range recentCaptures {
		out += md.H3(ufmt.Sprintf("Capture #%d", i+1))
		out += ufmt.Sprintf("**Telescope:** %s\n\n", capture.TelescopeID)
		out += ufmt.Sprintf("**Captured by:** %s\n\n", usernameOrAddressLink(capture.CapturedBy))
		out += ufmt.Sprintf("**Target:** RA %.8fh, Dec %.8f°\n\n", capture.TargetRA, capture.TargetDec)
		out += ufmt.Sprintf("**Exposure:** %d seconds\n\n", capture.Exposure)
		out += ufmt.Sprintf("**Image:** %s\n\n", md.Link("View", capture.ImageURL))
		out += md.HorizontalRule()
	}

	out += md.Link("← Back to main page", "/r/vik000/nightsky") + "\n\n"

	return out
}

func renderTelescopeMap() string {
	out := ""
	out += md.H1("NightSky - Telescope Map")
	out += "\n📍 Interactive map coming soon!\n\n"
	out += "For now, here are the telescope locations:\n\n"

	if len(telescopes) == 0 {
		out += "No telescopes registered yet.\n\n"
	} else {
		for _, config := range telescopes {
			out += ufmt.Sprintf("- **%s**: %.4f°, %.4f° (%s)\n\n",
				config.Name,
				config.Latitude,
				config.Longitude,
				config.Status,
			)
		}
	}

	out += md.Link("← Back to main page", "/r/vik000/nightsky") + "\n\n"

	return out
}
