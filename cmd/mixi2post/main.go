package main

import (
	"context"
	"fmt"
	"os"
	"strings"

	"mixi2post/internal/mixi2client"
        application_apiv1 "github.com/mixigroup/mixi2-application-sdk-go/gen/go/social/mixi/application/service/application_api/v1"
)

func main() {
    if len(os.Args) < 2 {
        fmt.Fprintln(os.Stderr, "usage: mixi2post <text>")
        os.Exit(1)
    }
    text := strings.Join(os.Args[1:], " ")

    if err := mixi2client.LoadEnvFile("~/.config/mixi2/env"); err != nil {
        fmt.Fprintln(os.Stderr, "warn: failed to load env file:", err)
    }

    client, ctx, err := mixi2client.New(context.Background())
    if err != nil {
        fmt.Fprintln(os.Stderr, "error:", err)
        fmt.Fprintln(os.Stderr, "hint: ~/.config/mixi2/env を確認してください")
        os.Exit(1)
    }
    defer client.Close()

    resp, err := client.Service.CreatePost(ctx, &application_apiv1.CreatePostRequest{
        Text: text,
    })
    if err != nil {
        fmt.Fprintln(os.Stderr, "CreatePost error:", err)
        os.Exit(1)
    }

    fmt.Println(resp.GetPost().GetPostId())
}
