package service

import (
	"bytes"
	"context"
	"embed"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

//go:embed darkssh_scripts/*.sh
var darksshScriptFS embed.FS

const darksshScriptDir = "darkssh_scripts"

// DarkSSHService runs a small, whitelisted set of helper scripts on the panel host (Linux).
type DarkSSHService struct{}

var darksshAllowed = map[string]string{
	"badvpn-install": "badvpn-install.sh",
	"stunnel-install": "stunnel-install.sh",
}

// DarkSSHStatus is returned by the panel API for the DarkSSH overview.
type DarkSSHStatus struct {
	Hostname       string `json:"hostname"`
	Kernel         string `json:"kernel"`
	OS             string `json:"os"`
	BadvpnUdpgw    bool   `json:"badvpnUdpgw"`
	Stunnel        bool   `json:"stunnel"`
	ScriptsAllowed bool   `json:"scriptsAllowed"`
}

// GetStatus collects lightweight host facts (no root required for most fields).
func (DarkSSHService) GetStatus() (*DarkSSHStatus, error) {
	h, _ := os.Hostname()
	st := &DarkSSHStatus{
		Hostname:       h,
		ScriptsAllowed: runtime.GOOS == "linux",
	}
	if out, err := exec.Command("uname", "-s").Output(); err == nil {
		st.OS = strings.TrimSpace(string(out))
	}
	if out, err := exec.Command("uname", "-r").Output(); err == nil {
		st.Kernel = strings.TrimSpace(string(out))
	}
	if _, err := exec.LookPath("badvpn-udpgw"); err == nil {
		st.BadvpnUdpgw = true
	}
	if _, err := exec.LookPath("stunnel4"); err == nil {
		st.Stunnel = true
	} else if _, err := exec.LookPath("stunnel"); err == nil {
		st.Stunnel = true
	}
	return st, nil
}

// RunWhitelistedScript writes an embedded script to a temp file and executes it with bash.
// name must be a key in darksshAllowed. Only Linux is supported.
func (DarkSSHService) RunWhitelistedScript(ctx context.Context, name string) (string, error) {
	if runtime.GOOS != "linux" {
		return "", fmt.Errorf("darkssh scripts are only supported on Linux hosts")
	}
	filename, ok := darksshAllowed[name]
	if !ok {
		return "", fmt.Errorf("unknown script")
	}
	rel := darksshScriptDir + "/" + filename
	data, err := darksshScriptFS.ReadFile(rel)
	if err != nil {
		return "", err
	}
	tmp, err := os.CreateTemp("", "x-ui-darkssh-*.sh")
	if err != nil {
		return "", err
	}
	tmpPath := tmp.Name()
	defer func() { _ = os.Remove(tmpPath) }()

	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		return "", err
	}
	if err := tmp.Chmod(0o700); err != nil {
		_ = tmp.Close()
		return "", err
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}

	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 15*time.Minute)
		defer cancel()
	}

	cmd := exec.CommandContext(ctx, "/bin/bash", tmpPath)
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	runErr := cmd.Run()
	return strings.TrimSpace(buf.String()), runErr
}
