package mixi2client

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	"github.com/mixigroup/mixi2-application-sdk-go/auth"
	application_apiv1 "github.com/mixigroup/mixi2-application-sdk-go/gen/go/social/mixi/application/service/application_api/v1"
)

const CONFIG_FILE = "~/.config/mixi2/env"

type Client struct {
	Service application_apiv1.ApplicationServiceClient
	conn    *grpc.ClientConn
}

func (c *Client) Close() {
	c.conn.Close()
}

func NewClient() (*Client, context.Context, error) {
	if err := loadEnvFile(CONFIG_FILE); err != nil {
		return nil, nil, fmt.Errorf("ERR_CONFIG: failed to load env file: %w", err)
	}

	clientID     := os.Getenv("CLIENT_ID")
	clientSecret := os.Getenv("CLIENT_SECRET")
	tokenURL     := os.Getenv("TOKEN_URL")
	apiAddress   := os.Getenv("API_ADDRESS")

	if clientID == "" || clientSecret == "" || tokenURL == "" || apiAddress == "" {
		return nil, nil, fmt.Errorf("ERR_AUTH: missing environment variables (CLIENT_ID=%t CLIENT_SECRET=%t TOKEN_URL=%t API_ADDRESS=%t)",
			clientID != "", clientSecret != "", tokenURL != "", apiAddress != "",
		)
	}

	authenticator, err := auth.NewAuthenticator(clientID, clientSecret, tokenURL)
	if err != nil {
		return nil, nil, fmt.Errorf("ERR_AUTH: authenticator creation failed: %w", err)
	}

	authCtx, err := authenticator.AuthorizedContext(context.Background())
	if err != nil {
		return nil, nil, fmt.Errorf("ERR_AUTH: authorized context acquisition failed: %w", err)
	}

	conn, err := grpc.NewClient(
		apiAddress,
		grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
	)
	if err != nil {
		return nil, nil, fmt.Errorf("ERR_CONN: gRPC connection failed: %w", err)
	}

	service := application_apiv1.NewApplicationServiceClient(conn)

	return &Client{Service: service, conn: conn}, authCtx, nil
}

func CreatePost(text string) (*application_apiv1.CreatePostResponse, error) {
	client, ctx, err := NewClient()
	if err != nil {
		return nil, err
	}
	defer client.Close()

	return client.Service.CreatePost(ctx, &application_apiv1.CreatePostRequest{
		Text: text,
	})
}

func DeletePost(id string) (*application_apiv1.DeletePostResponse, error) {
	client, ctx, err := NewClient()
	if err != nil {
		return nil, err
	}
	defer client.Close()

	return client.Service.DeletePost(ctx, &application_apiv1.DeletePostRequest{
		PostId: id,
	})
}

func loadEnvFile(path string) error {
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		path = home + path[1:]
	}

	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
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

		if os.Getenv(key) == "" {
			os.Setenv(key, val)
		}
	}
	return scanner.Err()
}
