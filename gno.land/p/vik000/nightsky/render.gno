package nightsky

import (
	"chain/runtime"
	"time"

	"gno.land/p/jeronimoalbi/mdform"
	"gno.land/p/moul/md"
	"gno.land/p/nt/ufmt"
)

// RenderNightsky generates the markdown output for the telescope realm.
// Call this from your realm's Render(path string) string function.
func (r *TelescopeRealm) RenderNightsky(path string) string {
	switch path {
	case "status":
		return r.renderStatus()
	case "commands":
		return r.renderCommandQueue()
	case "captures":
		return r.renderCaptureHistory()
	case "access":
		return r.renderAccessRules()
	case "commandData":
		return r.renderCommandData()
	case "control":
		return r.renderControl()
	default:
		return r.renderMainPage()
	}
}

func (r *TelescopeRealm) renderMainPage() string {
	out := "# " + r.Config.Name + " 🔭\n\n"

	statusIcon := "🔴"
	switch r.Config.Status {
	case "online":
		statusIcon = "🟢"
	case "busy":
		statusIcon = "🟡"
	case "error":
		statusIcon = "🔴"
	}

	out += statusIcon + " **Status:** " + r.Config.Status + "\n\n"
	out += "**Model:** " + r.Config.Model + "\n\n"
	out += ufmt.Sprintf("**Position:** %.2f°, %.2f°\n\n", r.Config.Latitude, r.Config.Longitude)

	out += "## Quick Stats\n\n"
	out += ufmt.Sprintf("📋 Commands in queue: %d\n\n", len(r.CommandQueue))
	out += ufmt.Sprintf("📸 Total captures: %d\n\n", len(r.CaptureHistory))
	out += ufmt.Sprintf("👥 Authorized users: %d\n\n", len(r.AccessRules))

	out += "## Quick Links\n\n"
	out += md.Link("🎮 Control Telescope", getPath(":control")) + " - Submit commands\n\n"
	out += md.Link("👥 Access Rules", getPath(":access")) + " - View and manage user access\n\n"
	out += md.Link("📋 Command Queue", getPath(":commands")) + "\n\n"
	out += md.Link("📸 Capture History", getPath(":captures")) + "\n\n"

	if len(r.CaptureHistory) > 0 {
		latest := r.CaptureHistory[0]
		out += "## Latest Capture\n\n"
		out += "![Latest capture](" + latest.ImageURL + ")\n\n"
		out += ufmt.Sprintf("_RA %.8fh · Dec %.8f° · %ds_\n\n", latest.TargetRA, latest.TargetDec, latest.Exposure)
	}

	out += "---\n\n"
	out += "## CLI Usage\n\n"
	out += "```\n"
	out += "gnokey maketx call -pkgpath \"gno.land" + r.Config.RealmPath + "\" \\\n"
	out += "  -func \"SubmitCommand\" \\\n"
	out += "  -args \"capture\" -args \"5.5\" -args \"22.5\" -args \"60\" \\\n"
	out += "  -gas-fee 1000000ugnot -gas-wanted 2000000 \\\n"
	out += "  -broadcast YOUR_ADDRESS\n"
	out += "```\n\n"

	out += md.Link("← Back to NightSky Network", "/r/vik000/nightsky") + "\n\n"
	return out
}

func (r *TelescopeRealm) renderControl() string {
	out := "# 🎮 Control Telescope\n\n"
	out += "**Note:** You must have access to submit commands.\n\n"
	out += "---\n\n"

	form := mdform.
		New("exec", "SubmitCommand").
		Select("commandType", "capture", "description", "Command type").
		Select("commandType", "stop").
		Input("targetRA", "placeholder", "0.0", "description", "Right Ascension (0–24h) — leave empty for stop").
		Input("targetDec", "placeholder", "0.0", "description", "Declination (−90–90°) — leave empty for stop").
		Input("exposure", "placeholder", "60", "description", "Exposure time in seconds (1–300) — leave empty for stop")

	out += form.String() + "\n\n"
	out += "---\n\n"
	out += md.Link("← Back", getPath("")) + "\n\n"
	return out
}

func (r *TelescopeRealm) renderCommandQueue() string {
	out := "# Command Queue\n\n"

	if len(r.CommandQueue) == 0 {
		out += "No pending commands.\n\n"
	} else {
		out += ufmt.Sprintf("%d command(s) pending:\n\n", len(r.CommandQueue))
		for i, cmd := range r.CommandQueue {
			out += ufmt.Sprintf("### Command #%d\n\n", i+1)
			out += "**Type:** " + cmd.CommandType + "\n\n"
			if cmd.CommandType == "capture" {
				out += ufmt.Sprintf("**Target:** RA %.8fh, Dec %.8f°\n\n", cmd.TargetRA, cmd.TargetDec)
				out += ufmt.Sprintf("**Exposure:** %d seconds\n\n", cmd.Exposure)
			}
			out += "**Requested by:** " + cmd.RequestedBy + "\n\n"
			out += "---\n\n"
		}
	}

	out += md.Link("← Back", getPath("")) + "\n\n"
	return out
}

func (r *TelescopeRealm) renderCaptureHistory() string {
	out := "# Capture History\n\n"

	if len(r.CaptureHistory) == 0 {
		out += "No captures yet.\n\n"
	} else {
		out += ufmt.Sprintf("Showing %d most recent captures:\n\n", len(r.CaptureHistory))
		for i, capture := range r.CaptureHistory {
			out += ufmt.Sprintf("### Capture #%d\n\n", i+1)
			out += ufmt.Sprintf("**Target:** RA %.8fh, Dec %.8f°\n\n", capture.TargetRA, capture.TargetDec)
			out += ufmt.Sprintf("**Exposure:** %d seconds\n\n", capture.Exposure)
			out += "**Captured by:** " + capture.CapturedBy + "\n\n"
			out += "**Image:** " + md.Link("View", capture.ImageURL) + "\n\n"
			out += "---\n\n"
		}
	}

	out += md.Link("← Back", getPath("")) + "\n\n"
	return out
}

func (r *TelescopeRealm) renderAccessRules() string {
	out := "# 👥 Access Rules\n\n"

	if len(r.AccessRules) == 0 {
		out += "No access rules configured. Only the owner can use the telescope.\n\n"
	} else {
		out += ufmt.Sprintf("%d user(s) have access:\n\n", len(r.AccessRules))
		for _, rule := range r.AccessRules {
			out += "**User:** " + rule.AllowedAddress
			if rule.ExpiresAt.IsZero() {
				out += " (Expires: Never)\n\n"
			} else {
				out += " (Expires: " + rule.ExpiresAt.Format(time.RFC1123) + ")\n\n"
			}
			out += "---\n\n"
		}
	}

	out += "## Grant Access\n\n"
	out += mdform.
		New("exec", "GrantAccess").
		Input("address", "placeholder", "g1...", "description", "Gno address to grant access to").
		Input("durationDays", "placeholder", "0", "description", "Duration in days (0 = never expires)").
		String() + "\n\n"

	out += "## Revoke Access\n\n"
	out += mdform.
		New("exec", "RevokeAccess").
		Input("address", "placeholder", "g1...", "description", "Gno address to revoke").
		String() + "\n\n"

	out += "---\n\n"
	out += md.Link("← Back", getPath("")) + "\n\n"
	return out
}

// renderStatus returns a machine-readable status block for the telescope controller.
func (r *TelescopeRealm) renderStatus() string {
	out := ufmt.Sprintf("commands=%d\n", len(r.CommandQueue))
	out += "status=" + r.Config.Status
	return "```\n" + out + "\n```"
}

// renderCommandData returns the first queued command in a machine-readable block.
func (r *TelescopeRealm) renderCommandData() string {
	if len(r.CommandQueue) == 0 {
		return "```\nno_commands\n```"
	}
	cmd := r.CommandQueue[0]
	data := "type=" + cmd.CommandType + "\n"
	data += ufmt.Sprintf("ra=%.8f\n", cmd.TargetRA)
	data += ufmt.Sprintf("dec=%.8f\n", cmd.TargetDec)
	data += ufmt.Sprintf("exposure=%d\n", cmd.Exposure)
	data += "requester=" + cmd.RequestedBy
	return "```\n" + data + "\n```"
}

// getPath builds an absolute URL path for the current realm with an optional suffix.
func getPath(addon string) string {
	pkgPath := runtime.CurrentRealm().PkgPath()
	if len(pkgPath) > 9 && pkgPath[:9] == "gno.land/" {
		return pkgPath[8:] + addon
	}
	return pkgPath + addon
}

