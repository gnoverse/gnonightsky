package telescope

import (
	"chain/runtime"
	"strconv"

	ns "gno.land/p/vik000/nightsky"
	registry "gno.land/r/vik000/nightsky"
)

var telescope *ns.TelescopeRealm

func init() {
	owner := "g1f699cfulem8jvq69pxlm5eq945dzusptzkdrgz"

	config := ns.NewTelescopeConfig(
		"vik telescope", // name
		"Seestar S30",   // model

		// Do not use too precise coordinates to keep some privacy
		49.02,  // latitude
		1.15, 	// longitude
		owner,
		runtime.CurrentRealm().PkgPath(),
	)

	telescope = ns.NewTelescopeRealm(&config)
	telescope.Config.UpdateStatus("online")
	registry.Register(cross, config)
}

func Render(path string) string {
	return telescope.RenderNightsky(path)
}

// SubmitCommand allows authorized users to submit telescope commands.
// commandType: "capture" or "stop"
// targetRA: Right Ascension in hours (0-24), leave empty for stop
// targetDec: Declination in degrees (-90 to 90), leave empty for stop
// exposure: Exposure time in seconds (1-300), leave empty for stop
func SubmitCommand(_ realm, commandType, targetRA, targetDec, exposure string) {
	caller := runtime.OriginCaller().String()
	ra, _ := strconv.ParseFloat(targetRA, 64)
	dec, _ := strconv.ParseFloat(targetDec, 64)
	exp, _ := strconv.Atoi(exposure)
	telescope.SubmitCommand(caller, commandType, ra, dec, exp)
}

// GrantAccess allows the owner to grant access to another user.
// durationDays: 0 = never expires
func GrantAccess(_ realm, address string, durationDays int) {
	caller := runtime.OriginCaller().String()
	telescope.GrantAccess(caller, address, durationDays)
}

// RevokeAccess allows the owner to revoke access from a user.
func RevokeAccess(_ realm, address string) {
	caller := runtime.OriginCaller().String()
	telescope.RevokeAccess(caller, address)
}

// GetNextCommand returns and removes the next command from the queue.
// Called by the telescope controller.
func GetNextCommand(_ realm) ns.TelescopeCommand {
	caller := runtime.OriginCaller().String()
	return telescope.GetNextCommand(caller)
}

// UpdateStatus updates the telescope status locally and in the NightSky registry.
// Valid values: "online", "offline", "busy", "error"
func UpdateStatus(cur realm, status string) {
	switch status {
	case "online", "offline", "busy", "error":
	default:
		panic("invalid status: must be online, offline, busy, or error")
	}
	caller := runtime.OriginCaller().String()
	telescope.UpdateStatus(caller, status)
	registry.UpdateTelescopeStatus(cross, status)
}

// RecordCapture records a capture result locally and submits it to the NightSky network feed.
func RecordCapture(cur realm, imageURL string, targetRA, targetDec float64, exposure int, capturedBy string) {
	caller := runtime.OriginCaller().String()
	telescope.RecordCapture(caller, imageURL, targetRA, targetDec, exposure, capturedBy)
	registry.SubmitCapture(cross, imageURL, targetRA, targetDec, exposure, capturedBy)
}

// ClearCommandQueue clears all pending commands (emergency stop).
func ClearCommandQueue(_ realm) {
	caller := runtime.OriginCaller().String()
	telescope.ClearCommandQueue(caller)
}

func GetCommandCount() int    { return telescope.GetCommandCount() }
func GetCaptureCount() int    { return telescope.GetCaptureCount() }
func GetAccessRuleCount() int { return telescope.GetAccessRuleCount() }
func GetStatus() string       { return telescope.Config.Status }
func GetTelescopeName() string { return telescope.Config.Name }
func GetTelescopeModel() string { return telescope.Config.Model }
func GetOwner() string        { return telescope.OwnerAddress }
