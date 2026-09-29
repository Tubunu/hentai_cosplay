package libbox

type InProcessPlatformInterface struct{}

func (i *InProcessPlatformInterface) LocalDNSTransport() LocalDNSTransport { return nil }
func (i *InProcessPlatformInterface) UsePlatformAutoDetectInterfaceControl() bool { return false }
func (i *InProcessPlatformInterface) AutoDetectInterfaceControl(fd int32) error { return nil }
func (i *InProcessPlatformInterface) OpenTun(options TunOptions) (int32, error) { return -1, nil }
func (i *InProcessPlatformInterface) UseProcFS() bool { return false }
func (i *InProcessPlatformInterface) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (*ConnectionOwner, error) { return nil, nil }
func (i *InProcessPlatformInterface) StartDefaultInterfaceMonitor(listener InterfaceUpdateListener) error { return nil }
func (i *InProcessPlatformInterface) CloseDefaultInterfaceMonitor(listener InterfaceUpdateListener) error { return nil }
func (i *InProcessPlatformInterface) GetInterfaces() (NetworkInterfaceIterator, error) { return nil, nil }
func (i *InProcessPlatformInterface) UnderNetworkExtension() bool { return false }
func (i *InProcessPlatformInterface) IncludeAllNetworks() bool { return false }
func (i *InProcessPlatformInterface) ReadWIFIState() *WIFIState { return nil }
func (i *InProcessPlatformInterface) ClearDNSCache() {}
func (i *InProcessPlatformInterface) SendNotification(notification *Notification) error { return nil }
func (i *InProcessPlatformInterface) CancelNotification(identifier string, typeID int32) error { return nil }
func (i *InProcessPlatformInterface) StartNeighborMonitor(listener NeighborUpdateListener) error { return nil }
func (i *InProcessPlatformInterface) CloseNeighborMonitor(listener NeighborUpdateListener) error { return nil }
func (i *InProcessPlatformInterface) RegisterMyInterface(name string) {}
func (i *InProcessPlatformInterface) UsePlatformShell() bool { return false }
func (i *InProcessPlatformInterface) CheckPlatformShell() error { return nil }
func (i *InProcessPlatformInterface) OpenShellSession(user *PlatformUser, command string, environ StringIterator, term string, rows int32, cols int32) (ShellSession, error) { return nil, nil }
func (i *InProcessPlatformInterface) LookupUser(username string) (*PlatformUser, error) { return nil, nil }
func (i *InProcessPlatformInterface) LookupSFTPServer() (string, error) { return "", nil }
func (i *InProcessPlatformInterface) ReadSystemSSHHostKey() (string, error) { return "", nil }
func (i *InProcessPlatformInterface) TailscaleHostname() string { return "" }
func (i *InProcessPlatformInterface) UsePlatformBridge() bool { return false }
func (i *InProcessPlatformInterface) CreateBridge(options *BridgeOptions) (BridgeSession, error) { return nil, nil }
func (i *InProcessPlatformInterface) UsePlatformAutoRedirect() bool { return false }
func (i *InProcessPlatformInterface) CreateAutoRedirect(options []byte, handler AutoRedirectHandler) (AutoRedirectSession, error) { return nil, nil }

type InProcessCommandHandler struct{}

func (h *InProcessCommandHandler) ServiceStop() error { return nil }
func (h *InProcessCommandHandler) ServiceReload() error { return nil }
func (h *InProcessCommandHandler) GetSystemProxyStatus() (*SystemProxyStatus, error) {
 return &SystemProxyStatus{Available: false, Enabled: false}, nil
}
func (h *InProcessCommandHandler) SetSystemProxyEnabled(enabled bool) error { return nil }
func (h *InProcessCommandHandler) TriggerNativeCrash() error { return nil }
func (h *InProcessCommandHandler) WriteDebugMessage(message string) {}
func (h *InProcessCommandHandler) ConnectSSHAgent() (int32, error) { return -1, nil }

func NewInProcessCommandServer() (*CommandServer, error) {
 return NewCommandServer(&InProcessCommandHandler{}, &InProcessPlatformInterface{})
}
