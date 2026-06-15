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
		// err の内容をログに出力したあと、os.Exit(1) を呼んだのと同じようにプログラムを終了させる
		log.Fatal(err)
	}

	// authenticator.AuthorizedContext(...) は、そのコンテキストに認証情報を付け足したものを返す
	// context.Background() は、Go でよく使う「空の土台」。キャンセル情報や期限をまだ持たない、
	// 最初のコンテキストとして使う。
	ctx, err := authenticator.AuthorizedContext(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	// 「API サーバーへ、安全な gRPC 接続を作る」 ための処理
	// conn はサーバーとの通信路そのもの
	conn, err := grpc.NewClient(
		apiAddress,
		// NewClientTLSFromCert(nil, "")はTLS 用の認証情報を作っている。nil は
		// 「証明書のプールを特に指定しない」。"" は「サーバー名の上書きをしない」。
		grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
	)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	// gRPC の接続 conn を使って、ApplicationService を呼び出すためのクライアントを作っている
	// client は、その通信路の上で「どのサービスの、どのメソッドを呼ぶか」を扱うための窓口
	client := application_apiv1.NewApplicationServiceClient(conn)

	// gRPC の CreatePost というメソッドを呼び出して、投稿を作成している
	resp, err := client.CreatePost(ctx, &application_apiv1.CreatePostRequest{
		Text: text,
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "CreatePost error:", err)
		os.Exit(1)
	}

	fmt.Println(resp.GetPost().GetPostId())
}
