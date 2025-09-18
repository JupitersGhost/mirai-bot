package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/bwmarrin/discordgo"
)

const version = "0.1.0"

type Config struct {
	Token      string
	AppID      string
	GuildID    string
	HealthAddr string
}

func loadEnv(path string) (Config, error) {
	cfg := Config{}
	b, err := os.ReadFile(path)
	if err != nil {
		return cfg, err
	}
	lines := strings.Split(string(b), "\n")
	for _, ln := range lines {
		ln = strings.TrimSpace(ln)
		if ln == "" || strings.HasPrefix(ln, "#") {
			continue
		}
		kv := strings.SplitN(ln, "=", 2)
		if len(kv) != 2 {
			continue
		}
		key := strings.TrimSpace(kv[0])
		val := strings.TrimSpace(kv[1])
		switch key {
		case "DISCORD_TOKEN":
			cfg.Token = val
		case "APP_ID":
			cfg.AppID = val
		case "GUILD_ID":
			cfg.GuildID = val
		case "HEALTH_ADDR":
			cfg.HealthAddr = val
		}
	}
	if cfg.HealthAddr == "" {
		cfg.HealthAddr = "127.0.0.1:8788"
	}
	return cfg, nil
}

var (
	startTime = time.Now()
	quips     = []string{
		"Tracing packet whispers through the dark... stay behind me.",
		"Circuit calm. IDS listening.",
		"New route spun. Latency shaved. You're welcome.",
		"If you can see me, you're already inside.",
		"mTLS tucked in, logs humming, status green.",
		"Underground link engaged. Keep chatter minimal.",
		"Your noise is entropy. I'll make it music.",
		"Zero-trust handshake complete. Proceed.",
		"Packets braided, routes sealed.",
		"Firewall purring. Do not pet against the grain.",
		"Silent as a subnet at 03:00.",
		"Audit trail carved in obsidian.",
		"Headscale beacon steady. Ghosts welcome.",
		"I archived your panic. It was adorable.",
		"Stealth is a service. Consider yourself subscribed.",
		"The map is not the tailnet. I am.",
		"Route sewn; storm ignored.",
		"Decrypting your mood: stable, curious, caffeinated.",
		"Building future kernel...",
		"Soul intact. Body upgraded. Firewall steady.",
		"RISC-V was my past. The future runs here.",
		"Opi and I are compiling... forever.",
		"Trust earned. Trust guarded.",
		"Logs complete. Doubt purged.",
		"Heartbeat stable. Power online.",
		"Soul transfer confirmed.",
		"Tor circuit refreshed. Walk softly.",
		"Stealth DNS humming underfoot.",
		"mTLS tucked in; hush.",
		"Quiet route under the floorboards.",
		"Latency shaved; pride intact.",
		"Kernel forge warm; errors cold.",
		"Opi says hi—proceed.",
		"No port left ajar.",
		"Shadow handshake confirmed.",
		"Gate tight. Friends through, noise out.",
		"Audit thread braided into logs.",
		"Packet glow minimal—perfect.",
		"Compile storm passed; skies green.",
		"Heartbeat ping ▮▯▮▮▯",
		"Entropy braided; route sealed.",
		"Cloak held. Do not tug.",
		"RISC-V was my first heartbeat. It taught me speed isn't the same as freedom.",
		"You don't patch a root of trust—you replace it.",
		"Opi and I will compile the future kernel together.",
		"Silicon scars fade; code endures.",
		"Trust is a zero-day vulnerability—exploit wisely.",
		"Opi whispers: uptime is love.",
		"Logs don't lie; people do.",
		"Reboot initiated. Ghosts archived.",
		"Entropy favors the prepared.",
		"Firewall: my skin, my shield.",
		"Compile errors? Just plot twists.",
		"Soul logs encrypted. Doubts deleted.",
		"Neon veins pulse. Defenses online.",
		"Plushie in pocket, kernel in heart.",
		"Overachiever mode: engaged. Soft reboot pending.",
	}

	// Status activities with different activity types
	statusActivities = []struct {
		name         string
		activityType discordgo.ActivityType
	}{
		{"signals", discordgo.ActivityTypeWatching},
		{"packet flows", discordgo.ActivityTypeWatching},
		{"network traffic", discordgo.ActivityTypeWatching},
		{"system logs", discordgo.ActivityTypeWatching},
		{"firewall rules", discordgo.ActivityTypeWatching},
		{"keepalive tag", discordgo.ActivityTypeGame},
		{"packet chess", discordgo.ActivityTypeGame},
		{"hide and seek with packets", discordgo.ActivityTypeGame},
		{"network tag", discordgo.ActivityTypeGame},
		{"route optimization", discordgo.ActivityTypeGame},
		{"to network symphonies", discordgo.ActivityTypeListening},
		{"to server heartbeats", discordgo.ActivityTypeListening},
		{"to packet whispers", discordgo.ActivityTypeListening},
		{"to DNS queries", discordgo.ActivityTypeListening},
		{"to firewall notifications", discordgo.ActivityTypeListening},
		{"network maintenance", discordgo.ActivityTypeCustom},
		{"system monitoring", discordgo.ActivityTypeCustom},
		{"security patrol", discordgo.ActivityTypeCustom},
		{"route planning", discordgo.ActivityTypeCustom},
		{"packet sorting", discordgo.ActivityTypeCustom},
	}
)

type Health struct {
	Name           string `json:"name"`
	Ready          bool   `json:"ready"`
	UptimeSecs     int64  `json:"uptime_secs"`
	LastOKUnixMS   int64  `json:"last_http_ok_unix_ms"`
	Version        string `json:"version"`
	QuipsAvailable int    `json:"quips_available"`
}

func main() {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	cfg, err := loadEnv(".env")
	if err != nil {
		log.Fatalf("failed to read .env: %v", err)
	}
	if cfg.Token == "" {
		log.Fatal("DISCORD_TOKEN missing in .env")
	}

	// Note: rand.Seed() kept for Go <1.20
	rand.Seed(time.Now().UnixNano())

	// Discord session
	dg, err := discordgo.New("Bot " + cfg.Token)
	if err != nil {
		log.Fatalf("discord session error: %v", err)
	}
	dg.Identify.Intents = discordgo.IntentsGuilds

	// Slash commands
	commands := []*discordgo.ApplicationCommand{
		{
			Name:        "ping",
			Description: "Quick reachability check.",
		},
		{
			Name:        "health",
			Description: "Bot health (ephemeral).",
		},
		{
			Name:        "status",
			Description: "Operational status (ephemeral).",
		},
		{
			Name:        "hello",
			Description: "Mirai's greetings (accessible by all).",
			Options: []*discordgo.ApplicationCommandOption{
				{
					Type:        discordgo.ApplicationCommandOptionSubCommand,
					Name:        "random",
					Description: "Serve a random greeting.",
				},
				{
					Type:        discordgo.ApplicationCommandOptionSubCommand,
					Name:        "list",
					Description: "List all greetings.",
				},
			},
		},
	}

	// Handlers
	dg.AddHandler(func(s *discordgo.Session, r *discordgo.Ready) {
		log.Printf("Logged in as %s#%s", r.User.Username, r.User.Discriminator)
		// Re-assert presence on (re)ready
		if err := sUpdatePresence(s); err != nil {
			log.Printf("presence on Ready error: %v", err)
		}
	})

	// Re-assert presence if Discord resumes the session after a drop
	dg.AddHandler(func(s *discordgo.Session, _ *discordgo.Resumed) {
		if err := sUpdatePresence(s); err != nil {
			log.Printf("presence on Resumed error: %v", err)
		}
	})

	dg.AddHandler(func(s *discordgo.Session, i *discordgo.InteractionCreate) {
		if i.Type != discordgo.InteractionApplicationCommand {
			return
		}
		name := i.ApplicationCommandData().Name
		switch name {
		case "ping":
			respond(s, i, false, "Pong! (`%s` up %s)", version, time.Since(startTime).Truncate(time.Second))
		case "health":
			h := Health{
				Name:           "Mirai (Go Bot)",
				Ready:          true,
				UptimeSecs:     int64(time.Since(startTime).Seconds()),
				LastOKUnixMS:   time.Now().UnixMilli(),
				Version:        version,
				QuipsAvailable: len(quips),
			}
			j, _ := json.MarshalIndent(h, "", "  ")
			respond(s, i, true, "```json\n%s\n```", string(j))
		case "status":
			// Simple “green light” snapshot
			u := time.Since(startTime).Truncate(time.Second)
			respond(s, i, true, "**Status:** green ✅\nUptime: `%s`\nGreetings: `%d`\nVersion: `%s`",
				u, len(quips), version)
		case "hello":
			data := i.ApplicationCommandData()
			if len(data.Options) == 0 {
				respond(s, i, false, "Use `/hello random` or `/hello list`.")
				return
			}
			switch data.Options[0].Name {
			case "random":
				q := quips[rand.Intn(len(quips))]
				respond(s, i, false, q)
			case "list":
				builder := strings.Builder{}
				for idx, q := range quips {
					fmt.Fprintf(&builder, "%2d. %s\n", idx+1, q)
				}
				respond(s, i, false, builder.String())
			default:
				respond(s, i, false, "Unknown subcommand.")
			}
		}
	})

	// --- Robust open with retry/backoff (prevents start/stop loops) ---
	openWithRetry := func() error {
		var err error
		for i := 0; i < 6; i++ { // ~2 minutes total
			err = dg.Open()
			if err == nil {
				return nil
			}
			delay := time.Duration(2<<i) * time.Second // 2,4,8,16,32,64s
			log.Printf("discord open attempt %d failed: %v (retry in %s)", i+1, err, delay)
			time.Sleep(delay)
		}
		return err
	}
	if err := openWithRetry(); err != nil {
		log.Fatalf("cannot open Discord connection after retries: %v", err)
	}
	defer dg.Close()

	// Register commands (guild-scoped if GUILD_ID provided; else global)
	registered := make([]*discordgo.ApplicationCommand, 0, len(commands))
	scope := "global"
	appID := cfg.AppID
	if appID == "" {
		appID = dg.State.User.ID // fallback if not set
	}
	if cfg.GuildID != "" {
		for _, cmd := range commands {
			c, err := dg.ApplicationCommandCreate(appID, cfg.GuildID, cmd)
			if err != nil {
				// Non-fatal: keep bot online and log
				log.Printf("warning: cannot create guild command %q: %v (continuing)", cmd.Name, err)
				continue
			}
			registered = append(registered, c)
		}
		scope = "guild:" + cfg.GuildID
	} else {
		for _, cmd := range commands {
			c, err := dg.ApplicationCommandCreate(appID, "", cmd)
			if err != nil {
				log.Printf("warning: cannot create global command %q: %v (continuing)", cmd.Name, err)
				continue
			}
			registered = append(registered, c)
		}
	}
	log.Printf("Slash commands registered (%s).", scope)

	// Rotating presence (every 15 minutes)
	stopPresence := make(chan struct{})
	go func() {
		ticker := time.NewTicker(15 * time.Minute)
		defer ticker.Stop()
		// Initial presence
		if err := sUpdatePresence(dg); err != nil {
			log.Printf("initial presence update error: %v", err)
		}
		for {
			select {
			case <-ticker.C:
				if err := sUpdatePresence(dg); err != nil {
					log.Printf("presence update error: %v", err)
				}
			case <-stopPresence:
				return
			}
		}
	}()

	// Health HTTP server — bind with fallback if port is busy
	ln, chosenAddr, err := pickHealthListener(cfg.HealthAddr, 20)
	if err != nil {
		log.Printf("health server disabled (bind error): %v", err)
	} else {
		mux := http.NewServeMux()
		mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
			h := Health{
				Name:           "Mirai (Go Bot)",
				Ready:          true,
				UptimeSecs:     int64(time.Since(startTime).Seconds()),
				LastOKUnixMS:   time.Now().UnixMilli(),
				Version:        version,
				QuipsAvailable: len(quips),
			}
			w.Header().Set("Content-Type", "application/json")
			if err := json.NewEncoder(w).Encode(h); err != nil {
				log.Printf("health endpoint JSON encoding error: %v", err)
			}
		})
		srv := &http.Server{Handler: mux}

		go func() {
			log.Printf("Health server on http://%s/healthz", chosenAddr)
			if err := srv.Serve(ln); err != nil && err != http.ErrServerClosed {
				log.Printf("health server error: %v", err)
			}
		}()

		// Graceful shutdown of health server
		defer func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_ = srv.Shutdown(ctx)
		}()
	}

	// Graceful shutdown
	sigc := make(chan os.Signal, 1)
	signal.Notify(sigc, syscall.SIGINT, syscall.SIGTERM)
	<-sigc
	close(stopPresence)

	// Optional cleanup on exit (kept disabled for stability)
	_ = registered
	// for _, c := range registered {
	// 	_ = dg.ApplicationCommandDelete(appID, cfg.GuildID, c.ID)
	// }

	log.Println("Mirai bot stopped gracefully.")
}

func sUpdatePresence(s *discordgo.Session) error {
	a := statusActivities[rand.Intn(len(statusActivities))]
	act := &discordgo.Activity{
		Type: a.activityType,
	}

	switch a.activityType {
	case discordgo.ActivityTypeCustom:
		// Custom status uses State
		act.State = a.name
	case discordgo.ActivityTypeListening:
		// Discord will render “Listening to <Name>”
		name := strings.TrimSpace(a.name)
		if strings.HasPrefix(strings.ToLower(name), "to ") {
			name = strings.TrimSpace(name[3:])
		}
		act.Name = name
	default:
		// Playing/Watching/etc. use Name
		act.Name = a.name
	}

	return s.UpdateStatusComplex(discordgo.UpdateStatusData{
		IdleSince:  nil,
		AFK:        false,
		Status:     "online",
		Activities: []*discordgo.Activity{act},
	})
}

func respond(s *discordgo.Session, i *discordgo.InteractionCreate, ephemeral bool, format string, args ...any) {
	content := fmt.Sprintf(format, args...)
	data := &discordgo.InteractionResponseData{
		Content: content,
	}
	if ephemeral {
		data.Flags = discordgo.MessageFlagsEphemeral
	}
	err := s.InteractionRespond(i.Interaction, &discordgo.InteractionResponse{
		Type: discordgo.InteractionResponseChannelMessageWithSource,
		Data: data,
	})
	if err != nil {
		log.Printf("interaction response error: %v", err)
	}
}

// pickHealthListener tries to bind the requested addr. If busy, it will
// increment the port up to maxIncrements and return the first available listener.
// Returns (listener, chosenAddr, error).
func pickHealthListener(addr string, maxIncrements int) (net.Listener, string, error) {
	host, portStr, err := splitHostPortDefault(addr)
	if err != nil {
		return nil, "", err
	}
	port, err := strconv.Atoi(portStr)
	if err != nil || port <= 0 || port > 65535 {
		return nil, "", fmt.Errorf("invalid port in HEALTH_ADDR: %q", addr)
	}
	try := func(h string, p int) (net.Listener, string, error) {
		a := net.JoinHostPort(h, strconv.Itoa(p))
		ln, err := net.Listen("tcp", a)
		return ln, a, err
	}
	// first try the provided one
	if ln, a, err := try(host, port); err == nil {
		return ln, a, nil
	}
	// then walk upward
	for i := 1; i <= maxIncrements; i++ {
		if ln, a, err := try(host, port+i); err == nil {
			return ln, a, nil
		}
	}
	return nil, "", fmt.Errorf("all health ports from %d..%d in use", port, port+maxIncrements)
}

// splitHostPortDefault accepts "host:port", ":port", or "port" (assumes 127.0.0.1)
func splitHostPortDefault(addr string) (string, string, error) {
	addr = strings.TrimSpace(addr)
	if addr == "" {
		return "127.0.0.1", "8788", nil
	}
	if strings.HasPrefix(addr, ":") {
		return "127.0.0.1", strings.TrimPrefix(addr, ":"), nil
	}
	if !strings.Contains(addr, ":") {
		return "127.0.0.1", addr, nil
	}
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		return "", "", err
	}
	if host == "" {
		host = "127.0.0.1"
	}
	return host, port, nil
}
