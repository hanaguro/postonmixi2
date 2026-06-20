package main

import (
	"fmt"
	"os"
	"strings"

	"mixi2post/internal/mixi2client"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: mixi2deletepost <postid>")
		os.Exit(1)
	}
	id := strings.Join(os.Args[1:], " ")

	_, err := mixi2client.DeletePost(id)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
