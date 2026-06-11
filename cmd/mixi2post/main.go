package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	"github.com/mixigroup/mixi2-application-sdk-go/auth"
	application_apiv1 "github.com/mixigroup/mixi2-application-sdk-go/gen/go/social/mixi/application/service/application_api/v1"
)

// envファイルを読み込んで環境変数にセットする
// 既にOSの環境変数に設定済みのものは上書きしない
func loadEnvFile(path string) error {
	// ~ を展開
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		path = home + path[1:]
	}

	f, err := os.Open(path)
	if err != nil {
		// ファイルが無くても致命的エラーにはしない（OS環境変数で渡す運用も許容）
		return nil
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		// 空行・コメント・export プレフィックスを無視
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		line = strings.TrimPrefix(line, "export ")

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.Trim(strings.TrimSpace(parts[1]), "'\"")

		// OS環境変数が既にある場合は上書きしない
		if os.Getenv(key) == "" {
			os.Setenv(key, val)
		}
	}
	return scanner.Err()
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: mixi2post <text>")
		os.Exit(1)
	}
	text := strings.Join(os.Args[1:], " ")

	// ~/.config/mixi2/env を読み込む（source 不要）
	if err := loadEnvFile("~/.config/mixi2/env"); err != nil {
		fmt.Fprintln(os.Stderr, "warn: failed to load env file:", err)
	}

	clientID     := os.Getenv("CLIENT_ID")
	clientSecret := os.Getenv("CLIENT_SECRET")
	tokenURL     := os.Getenv("TOKEN_URL")
	apiAddress   := os.Getenv("API_ADDRESS")

	if clientID == "" || clientSecret == "" || tokenURL == "" || apiAddress == "" {
		fmt.Fprintf(os.Stderr,
			"error: 必要な環境変数が未設定です (CLIENT_ID=%t CLIENT_SECRET=%t TOKEN_URL=%t API_ADDRESS=%t)\n",
			clientID != "", clientSecret != "", tokenURL != "", apiAddress != "")
		fmt.Fprintln(os.Stderr, "hint: ~/.config/mixi2/env を確認してください")
		os.Exit(1)
	}

	authenticator, err := auth.NewAuthenticator(clientID, clientSecret, tokenURL)
	if err != nil {
		log.Fatal(err)
	}

	ctx, err := authenticator.AuthorizedContext(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	conn, err := grpc.NewClient(
		apiAddress,
		grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
	)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	client := application_apiv1.NewApplicationServiceClient(conn)

	resp, err := client.CreatePost(ctx, &application_apiv1.CreatePostRequest{
		Text: text,
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "CreatePost error:", err)
		os.Exit(1)
	}

	fmt.Println(resp.GetPost().GetPostId())
}
