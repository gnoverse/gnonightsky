package nightsky

import (
	"chain/runtime"

	"gno.land/p/nt/ownable"
	"gno.land/p/vik000/nightsky"
)

var (
	OwnableMain = ownable.NewWithAddress("g13kytw9mpyutwmyg5eq7arqxqcszfl6uq4p89zg")
)

// RemoveTelescope allows admin to remove a telescope from the network
func RemoveTelescope(addr string) {
	checkPermission()

	_, exists := telescopes[addr]
	if !exists {
		panic("telescope not found")
	}

	delete(telescopes, addr)
}

// ClearAllTelescopes removes all telescopes (emergency use only)
func ClearAllTelescopes() {
	checkPermission()

	telescopes = make(map[string]nightsky.TelescopeConfig)
}

// ClearCaptures clears the recent captures list
func ClearCaptures() {
	checkPermission()

	recentCaptures = []nightsky.CaptureResult{}
}

// RemoveCapture removes a specific capture by index
func RemoveCapture(idx int) {
	checkPermission()

	if idx < 0 || idx >= len(recentCaptures) {
		panic("invalid capture index")
	}

	recentCaptures = append(recentCaptures[:idx], recentCaptures[idx+1:]...)
}

func checkPermission() {
	addr := runtime.PreviousRealm().Address()
	if addr == OwnableMain.Owner() {
		return
	}
	panic("access restricted")
}
