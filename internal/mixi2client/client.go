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

// Client は mixi2 API を呼ぶための認証済みクライアントをまとめた構造体。
// 他のアプリからも使い回せる。
type Client struct {
    // 外から CreatePost などを呼ぶための窓口
    Service application_apiv1.ApplicationServiceClient
    // Close を呼ぶために保持する
    conn *grpc.ClientConn
}

// Close は gRPC 接続を閉じる。
// 呼び出し元で defer client.Close() のように使う。
func (c *Client) Close() {
    c.conn.Close()
}

// NewClient は環境変数を読み込み、認証済みの Client を返す。
// ctx は認証情報が付いたコンテキストも返す。
func NewClient() (*Client, context.Context, error) {
    if err := loadEnvFile(CONFIG_FILE); err != nil {
	return nil, nil, fmt.Errorf(
		"warn: failed to load env file: %w", err)
    }

    clientID     := os.Getenv("CLIENT_ID")
    clientSecret := os.Getenv("CLIENT_SECRET")
    tokenURL     := os.Getenv("TOKEN_URL")
    apiAddress   := os.Getenv("API_ADDRESS")

    if clientID == "" || clientSecret == "" || tokenURL == "" || apiAddress == "" {
        return nil, nil, fmt.Errorf(
            "必要な環境変数が未設定です (CLIENT_ID=%t CLIENT_SECRET=%t TOKEN_URL=%t API_ADDRESS=%t)",
            clientID != "", clientSecret != "", tokenURL != "", apiAddress != "",
        )
    }

    authenticator, err := auth.NewAuthenticator(clientID, clientSecret, tokenURL)
    if err != nil {
        return nil, nil, fmt.Errorf("authenticator の作成に失敗しました: %w", err)
    }

    authCtx, err := authenticator.AuthorizedContext(context.Background())
    if err != nil {
        return nil, nil, fmt.Errorf("認証済みコンテキストの取得に失敗しました: %w", err)
    }

    conn, err := grpc.NewClient(
        apiAddress,
        grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
    )
    if err != nil {
        return nil, nil, fmt.Errorf("gRPC 接続の作成に失敗しました: %w", err)
    }

    service := application_apiv1.NewApplicationServiceClient(conn)

    return &Client{Service: service, conn: conn}, authCtx, nil
}

func CreatePost(text string) (*application_apiv1.CreatePostResponse, error) {
    client, ctx, err := NewClient()
    if err != nil {
	fmt.Fprintln(os.Stderr, "mixi2client error: hint: " + CONFIG_FILE + " を確認してください", err)
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
	fmt.Fprintln(os.Stderr, "mixi2client error: hint: " + CONFIG_FILE + " を確認してください", err)
	return nil, err
    }
    defer client.Close()

    return client.Service.DeletePost(ctx, &application_apiv1.DeletePostRequest{
	PostId: id,
    })
}

// envファイルを読み込んで環境変数にセットする
// 既にOSの環境変数に設定済みのものは上書きしない
func loadEnvFile(path string) error {
	// ~ を展開
	if strings.HasPrefix(path, "~/") {
		// := は Go の 短い変数宣言。「左辺の変数を新しく作って、右辺の値を入れる」という意味。 
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
	// 今すぐではなく、この関数が終わる直前に f.Close() を実行する
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
		// 右側の値から、余計な空白と引用符('と")を取り除いて、素の文字列にしている
		val := strings.Trim(strings.TrimSpace(parts[1]), "'\"")

		// OS環境変数が既にある場合は上書きしない
		if os.Getenv(key) == "" {
			os.Setenv(key, val)
		}
	}
	// 「正常終了なら nil、何か問題があればそのエラー」 を返している
	return scanner.Err()
}
