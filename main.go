package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
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
		name string
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

	// Note: rand.Seed() is deprecated in Go 1.20+, automatic seeding is used
	// Keeping for compatibility with older Go versions
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
			// Simple traffic-light; keep it minimal without extra deps.
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
				// Big message; still within Discord limits with this count.
				respond(s, i, false, builder.String())
			default:
				respond(s, i, false, "Unknown subcommand.")
			}
		}
	})

	// Open connection
	if err := dg.Open(); err != nil {
		log.Fatalf("cannot open Discord connection: %v", err)
	}
	defer dg.Close()

	// Register commands (guild-scoped if GUILD_ID provided; else global)
	registered := make([]*discordgo.ApplicationCommand, 0, len(commands))
	scope := "global"
	var appID = cfg.AppID
	if appID == "" {
		appID = dg.State.User.ID // fallback if not set
	}
	if cfg.GuildID != "" {
		for _, cmd := range commands {
			c, err := dg.ApplicationCommandCreate(appID, cfg.GuildID, cmd)
			if err != nil {
				log.Fatalf("cannot create guild command %q: %v", cmd.Name, err)
			}
			registered = append(registered, c)
		}
		scope = "guild:" + cfg.GuildID
	} else {
		for _, cmd := range commands {
			c, err := dg.ApplicationCommandCreate(appID, "", cmd)
			if err != nil {
				log.Fatalf("cannot create global command %q: %v", cmd.Name, err)
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
		// Kick an initial presence quickly
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

	// Health HTTP server
	srv := &http.Server{
		Addr: cfg.HealthAddr,
	}
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
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
	go func() {
		log.Printf("Health server on http://%s/healthz", cfg.HealthAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("health server error: %v", err)
		}
	}()

	// Graceful shutdown
	sigc := make(chan os.Signal, 1)
	signal.Notify(sigc, syscall.SIGINT, syscall.SIGTERM)
	<-sigc
	close(stopPresence)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("health server shutdown error: %v", err)
	}

	// Optional: clean up commands on exit (commented out for stability)
	// for _, c := range registered {
	// 	_ = dg.ApplicationCommandDelete(appID, cfg.GuildID, c.ID)
	// }
	log.Println("Mirai bot stopped gracefully.")
}

func sUpdatePresence(s *discordgo.Session) error {
	// Pick a random status activity
	activity := statusActivities[rand.Intn(len(statusActivities))]
	return s.UpdateStatusComplex(discordgo.UpdateStatusData{
		Activities: []*discordgo.Activity{{
			Name: activity.name, 
			Type: activity.activityType,
		}},
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