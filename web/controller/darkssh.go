package controller

import (
	"context"
	"errors"
	"regexp"
	"strconv"
	"strings"

	"github.com/mhsanaei/3x-ui/v3/web/service"

	"github.com/gin-gonic/gin"
)

// DarkSSHController exposes optional host helper actions (badvpn, stunnel) for advanced setups.
type DarkSSHController struct {
	svc service.DarkSSHService
}

var sshSubUserRe = regexp.MustCompile(`^[a-z][a-z0-9_-]{2,31}$`)

// NewDarkSSHController registers /panel/darkssh/* API routes (HTML page is registered on XUIController).
func NewDarkSSHController(g *gin.RouterGroup) *DarkSSHController {
	a := &DarkSSHController{}
	sub := g.Group("/darkssh")
	sub.GET("/status", a.status)
	sub.POST("/badvpn/install", a.badvpnInstall)
	sub.POST("/stunnel/install", a.stunnelInstall)
	sub.POST("/ssh/users/list", a.sshUsersList)
	sub.POST("/ssh/user/add", a.sshUserAdd)
	sub.POST("/ssh/user/del", a.sshUserDel)
	sub.POST("/conn/ipforward/on", a.connIPForwardOn)
	sub.POST("/conn/ipforward/off", a.connIPForwardOff)
	sub.POST("/badvpn/systemd/install", a.badvpnSystemdInstall)
	sub.POST("/systemd/daemon-reload", a.systemdDaemonReload)
	sub.POST("/stunnel/sample/conf", a.stunnelSampleConf)
	return a
}

type sshUserAddForm struct {
	SubUsername string `form:"subUsername"`
	SubPassword string `form:"subPassword"`
}

type sshUserDelForm struct {
	SubUsername string `form:"subUsername"`
}

type badvpnSystemdForm struct {
	UdpgwPort int `form:"udpgwPort"`
}

func (a *DarkSSHController) status(c *gin.Context) {
	st, err := a.svc.GetStatus()
	if err != nil {
		jsonMsg(c, I18nWeb(c, "pages.darkssh.toasts.status"), err)
		return
	}
	jsonObj(c, st, nil)
}

func (a *DarkSSHController) badvpnInstall(c *gin.Context) {
	a.runScript(c, "badvpn-install", nil)
}

func (a *DarkSSHController) stunnelInstall(c *gin.Context) {
	a.runScript(c, "stunnel-install", nil)
}

func (a *DarkSSHController) sshUsersList(c *gin.Context) {
	out, err := a.svc.RunWhitelistedScript(context.Background(), "ssh-users-list", nil)
	users := parseUserLines(out)
	if err != nil {
		jsonObj(c, gin.H{"users": users, "output": out}, err)
		return
	}
	jsonObj(c, gin.H{"users": users, "output": out}, nil)
}

func (a *DarkSSHController) sshUserAdd(c *gin.Context) {
	form := &sshUserAddForm{}
	if err := c.ShouldBind(form); err != nil {
		jsonMsg(c, I18nWeb(c, "pages.darkssh.toasts.invalidForm"), err)
		return
	}
	form.SubUsername = strings.TrimSpace(form.SubUsername)
	if err := validateSSHSubUsername(form.SubUsername); err != nil {
		jsonMsg(c, I18nWeb(c, "pages.darkssh.toasts.invalidUsername"), err)
		return
	}
	if err := validateSSHSubPassword(form.SubPassword); err != nil {
		jsonMsg(c, I18nWeb(c, "pages.darkssh.toasts.invalidPassword"), err)
		return
	}
	env := []string{
		"DARKSSH_SUBUSER=" + form.SubUsername,
		"DARKSSH_SUBPASS=" + form.SubPassword,
	}
	a.runScript(c, "ssh-user-add", env)
}

func (a *DarkSSHController) sshUserDel(c *gin.Context) {
	form := &sshUserDelForm{}
	if err := c.ShouldBind(form); err != nil {
		jsonMsg(c, I18nWeb(c, "pages.darkssh.toasts.invalidForm"), err)
		return
	}
	form.SubUsername = strings.TrimSpace(form.SubUsername)
	if err := validateSSHSubUsername(form.SubUsername); err != nil {
		jsonMsg(c, I18nWeb(c, "pages.darkssh.toasts.invalidUsername"), err)
		return
	}
	env := []string{"DARKSSH_SUBUSER=" + form.SubUsername}
	a.runScript(c, "ssh-user-del", env)
}

func (a *DarkSSHController) connIPForwardOn(c *gin.Context) {
	a.runScript(c, "conn-ipforward-on", nil)
}

func (a *DarkSSHController) connIPForwardOff(c *gin.Context) {
	a.runScript(c, "conn-ipforward-off", nil)
}

func (a *DarkSSHController) badvpnSystemdInstall(c *gin.Context) {
	form := &badvpnSystemdForm{}
	if err := c.ShouldBind(form); err != nil {
		jsonMsg(c, I18nWeb(c, "pages.darkssh.toasts.invalidForm"), err)
		return
	}
	port := form.UdpgwPort
	if port <= 0 {
		port = 7300
	}
	if port < 1024 || port > 65535 {
		jsonMsg(c, I18nWeb(c, "pages.darkssh.toasts.badPort"), errors.New("invalid port"))
		return
	}
	env := []string{"DARKSSH_UDPGW_PORT=" + strconv.Itoa(port)}
	a.runScript(c, "badvpn-systemd-install", env)
}

func (a *DarkSSHController) systemdDaemonReload(c *gin.Context) {
	a.runScript(c, "systemd-daemon-reload", nil)
}

func (a *DarkSSHController) stunnelSampleConf(c *gin.Context) {
	a.runScript(c, "stunnel-sample-conf", nil)
}

func (a *DarkSSHController) runScript(c *gin.Context, key string, extraEnv []string) {
	out, err := a.svc.RunWhitelistedScript(context.Background(), key, extraEnv)
	jsonObj(c, gin.H{"output": out}, err)
}

func parseUserLines(out string) []string {
	var users []string
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			users = append(users, line)
		}
	}
	return users
}

func validateSSHSubUsername(name string) error {
	if !sshSubUserRe.MatchString(name) {
		return errors.New("invalid username")
	}
	return nil
}

func validateSSHSubPassword(pass string) error {
	if len(pass) < 8 || len(pass) > 128 {
		return errors.New("password length")
	}
	if strings.ContainsAny(pass, ":\n\r\x00") {
		return errors.New("password contains forbidden characters")
	}
	return nil
}
