# PostOnMixi2
## 概要
PostOnMixi2は、以下の機能を提供します。
* mixi2への投稿を行なうmixi2post(goプログラム)
* mixi2の投稿を削除するmixi2deletepost(goプログラム)
* neovimからmixi2postを使用して投稿を行なうプラグイン (Bluesky・Xへの同時投稿機能あり)


使用するにはmixi2 Developer Platformを使用するためにmixi2 アカウントに対して開発者登録を行なう必要があります。  
  
mixi2 Developer Platformの[アプリケーションの概念](https://developer.mixi.social/docs/getting-started/concepts)にあるように、mixi2post/mixi2deletepostを使用する専用のアカウントからの投稿になります。  
現状では、既に取得しているmixi2アカウントに対してmixi2post/mixi2deletepostを使用することはできません。

## ビルド
Makefileがありますので、次のコマンドでビルドしてください。
```bash
make build
```
make buildを行なうとデフォルトでは~/bin/以下にmixi2post/mixi2deletepostを出力します。
```bash
make BIN_DIR=~/bin2 build
```
とすることで~/bin2/以下にmixi2post/mixi2deletepostを出力します。  
PATHの通ったところにmixi2post/mixi2deletepostを出力するようにしてください。

## 使い方
### ~/.config/mixi2/env
mixi2のClient ID、Client Secret、Token URL、API Addressを記述するファイルです。  
このファイルに記述されているClient ID、Client Secret、Token URL、API Addressを使用して、mixi2post/mixi2deletepostを使用することが出来ます。

> CLIENT_ID=Client IDを記述  
> CLIENT_SECRET=Client Secretを記述  
> TOKEN_URL=Token URLを記述  
> API_ADDRESS=API Addressを記述  
  
環境変数に上記の項目を設定しても使用することができ、~/.config/mixi2/envより環境変数が優先されます。

### mixi2post
mixi2postは、mixi2アカウントに対して投稿を行なうためのコマンドです。  
投稿を行なうだけです。
```bash
mixi2post <投稿内容>
```

### mixi2deletepost
mixi2deletepostは、mixi2アカウントに対して投稿を削除するためのコマンドです。  
削除を行なうだけです。  
Post IDはPCのブラウザから削除したい投稿を開き、そのURLから取得することができます。
```bash
mixi2deletepost <Post ID>
```

### neovimプラグイン
* lazyを使用している場合
```lua
	{
		"hanaguro/postonmixi2",
		config = function()
		  require("postonmixi2").setup({
		    keymap = "s",
		    bluesky = true, -- Blueskyへ同時に投稿する場合に設定
            x = true, -- Xへ同時に投稿する場合に設定
		  })
		end,
	}
```
この設定例の場合、sを押すことでneovimからmixi2postを使用して投稿を行なうことができます。`bluesky = true` に設定している場合、同時にBlueskyへも投稿されます。

#### Bluesky投稿について
Blueskyへの同時投稿機能を利用するには、別途 `bsky` コマンドが必要です。以下のリポジトリから取得し、`bsky post` コマンドで投稿ができる状態に設定してください。
https://github.com/mattn/bsky

#### X (Twitter) 投稿について
Xへの同時投稿機能を利用する場合、投稿内容を含んだ状態でXの投稿画面がブラウザで立ち上がります。API連携ではなくブラウザ経由での投稿となるため、ブラウザ側で投稿を確定させてください。

