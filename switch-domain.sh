#!/usr/bin/env bash
# visions-match-lp を visions.goodwillhunting.co.jp に切り替える
#
# ⚠️ 実行前に必ずDNSを設定しておくこと（お名前.com）:
#     ホスト名: visions / TYPE: CNAME / VALUE: shinmi725810-sketch.github.io.
#
# DNS未設定のまま実行するとLPが両方のURLで見られなくなります。
# そのためスクリプト冒頭でDNSの解決を検証し、通らなければ中断します。

set -euo pipefail
cd "$(dirname "$0")"

NEW_HOST="visions.goodwillhunting.co.jp"
OLD_URL="https://shinmi725810-sketch.github.io/visions-match-lp/"
NEW_URL="https://${NEW_HOST}/"

echo "▶ 1/5 DNSの検証"
RESOLVED="$(dig +short "$NEW_HOST" CNAME || true)"
if [ -z "$RESOLVED" ]; then
  RESOLVED="$(dig +short "$NEW_HOST" A || true)"
fi
if [ -z "$RESOLVED" ]; then
  echo "❌ 中断: $NEW_HOST がDNSで解決できません。"
  echo "   お名前.comでCNAMEレコードを追加し、反映（最大数時間）を待ってから再実行してください。"
  exit 1
fi
echo "  ✅ 解決OK: $RESOLVED"

echo "▶ 2/5 CNAMEファイルを作成"
printf '%s\n' "$NEW_HOST" > CNAME
echo "  ✅ CNAME → $NEW_HOST"

echo "▶ 3/5 canonical / og:url / twitter を新ドメインへ書き換え"
python3 - "$OLD_URL" "$NEW_URL" <<'PY'
import sys, pathlib
old, new = sys.argv[1], sys.argv[2]
total = 0
for f in ("index.html", "lp-shimei.html"):
    p = pathlib.Path(f)
    s = p.read_text(encoding="utf-8")
    n = s.count(old)
    if n:
        p.write_text(s.replace(old, new), encoding="utf-8")
    print(f"  {f}: {n}箇所を置換")
    total += n
print(f"  合計 {total}箇所")
PY

echo "▶ 4/5 Google広告のサイト所有権確認ファイルを確認"
if ls googlead*.html >/dev/null 2>&1; then
  echo "  ✅ $(ls googlead*.html) は同一リポジトリ内のため新ドメインでも配信されます"
  echo "  ⚠️ ただしGoogle広告側で「所有権の再確認」が必要です（新ドメインで登録し直し）"
else
  echo "  ⚠️ 所有権確認ファイルが見つかりません"
fi

echo "▶ 5/5 コミット＆プッシュ"
git add -A
git commit -m "chore: 独自ドメイン ${NEW_HOST} へ移行

- CNAMEファイルを追加
- canonical / og:url / twitter:url を新ドメインへ更新"
git push origin gh-pages

echo
echo "✅ 完了。次にGitHub側で以下を確認してください:"
echo "   Settings → Pages → Custom domain が ${NEW_HOST} になっているか"
echo "   「Enforce HTTPS」は証明書発行後（最大24h）にONにする"
echo
echo "▼ 反映確認"
echo "   curl -I ${NEW_URL}"
