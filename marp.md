# Marpによるスライド作成

## Marp

今回、**Marp**を用いてスライドをMarkdownで記述・作成した

[slides.md](./slides.md) は、VS Code の Marp プラグインを利用して作成されている

### Marp for VS Code
VS Code エディタのプラグイン検索から `Marp for VS Code` をインストールすると、Markdownファイルをスライドとしてプレビューできるようになる

対象のMarkdownファイルは先頭で以下のような設定を記述する必要がある

```markdown
---
marp: true
---
<!-- $theme: gaia -->
<!-- $size: 4:3 -->
<!-- page_number: true -->
<!-- paginate: true -->
```

`$theme` や `$size` などは、自分の気に入った設定を記述すれば良い

### Marp CLI
VS Code プラグインだけでは、pptx形式にエクスポートすることはできない（pdf形式等なら可能）

そのため、**Marp CLI** を使う必要がある

Marp CLI は Node.js がインストールされている環境であれば、以下のコマンドで実行可能である

```bash
# Marp CLI を用いて slides.md を slides.pptx にエクスポート
$ npx @marp-team/marp-cli slides.md -o slides.pptx
```
