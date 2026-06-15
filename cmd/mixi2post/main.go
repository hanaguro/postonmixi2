package main

import (
	"fmt"
	"os"
	"strings"

	"mixi2post/internal/mixi2client"
)

func main() {
    if len(os.Args) < 2 {
        fmt.Fprintln(os.Stderr, "usage: mixi2post <text>")
        os.Exit(1)
    }
    text := strings.Join(os.Args[1:], " ")

    resp, err := mixi2client.CreatePost(text)
    if err != nil {
        fmt.Fprintln(os.Stderr, "CreatePost error:", err)
        os.Exit(1)
    }

    fmt.Println(resp.GetPost().GetPostId())
}
