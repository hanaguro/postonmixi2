package main

import (
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

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: mixi2post <text>")
		os.Exit(1)
	}
	text := strings.Join(os.Args[1:], " ")

	clientID     := os.Getenv("MIXI2_CLIENT_ID")
	clientSecret := os.Getenv("MIXI2_CLIENT_SECRET")
	tokenURL     := os.Getenv("MIXI2_TOKEN_URL")
	apiAddress   := os.Getenv("MIXI2_API_ADDRESS") // 例: api.mixi.social:443

	if clientID == "" || clientSecret == "" || tokenURL == "" || apiAddress == "" {
		fmt.Fprintln(os.Stderr, "error: MIXI2_CLIENT_ID / MIXI2_CLIENT_SECRET / MIXI2_TOKEN_URL / MIXI2_API_ADDRESS が未設定です")
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
