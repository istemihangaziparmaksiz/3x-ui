package controller

import (
	"context"

	"github.com/mhsanaei/3x-ui/v3/web/service"

	"github.com/gin-gonic/gin"
)

// DarkSSHController exposes optional host helper actions (badvpn, stunnel) for advanced setups.
type DarkSSHController struct {
	svc service.DarkSSHService
}

// NewDarkSSHController registers /panel/darkssh/* API routes (HTML page is registered on XUIController).
func NewDarkSSHController(g *gin.RouterGroup) *DarkSSHController {
	a := &DarkSSHController{}
	sub := g.Group("/darkssh")
	sub.GET("/status", a.status)
	sub.POST("/badvpn/install", a.badvpnInstall)
	sub.POST("/stunnel/install", a.stunnelInstall)
	return a
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
	a.runScript(c, "badvpn-install")
}

func (a *DarkSSHController) stunnelInstall(c *gin.Context) {
	a.runScript(c, "stunnel-install")
}

func (a *DarkSSHController) runScript(c *gin.Context, key string) {
	out, err := a.svc.RunWhitelistedScript(context.Background(), key)
	jsonObj(c, gin.H{"output": out}, err)
}
