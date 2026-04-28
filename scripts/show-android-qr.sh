#!/usr/bin/env sh
set -eu

PEER_NAME="${1:-android1}"
QR_FILE="wireguard/config/peer_${PEER_NAME}/peer_${PEER_NAME}.png"
CONF_FILE="wireguard/config/peer_${PEER_NAME}/peer_${PEER_NAME}.conf"

case "$PEER_NAME" in
  *[!A-Za-z0-9_-]*)
    echo "Nome peer non valido: $PEER_NAME" >&2
    exit 1
    ;;
esac

if [ ! -f "$CONF_FILE" ]; then
  echo "Profilo non trovato: $CONF_FILE" >&2
  echo "Avvia prima: ./scripts/start.sh" >&2
  exit 1
fi

docker_compose() {
  if docker ps >/dev/null 2>&1; then
    docker compose "$@"
  else
    sudo docker compose "$@"
  fi
}

if docker_compose exec -T wireguard sh -c "command -v qrencode >/dev/null 2>&1"; then
  docker_compose exec -T wireguard sh -c "qrencode -t ansiutf8 < /config/peer_${PEER_NAME}/peer_${PEER_NAME}.conf"
  exit 0
fi

if [ -f "$QR_FILE" ]; then
  echo "QR code disponibile come immagine: $QR_FILE"
  echo "Il container non espone qrencode nel terminale, ma il PNG e' gia' stato generato."
  exit 0
fi

echo "QR code non disponibile. Controlla i log con: docker compose logs wireguard" >&2
exit 1
