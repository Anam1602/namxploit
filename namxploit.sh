#!/bin/bash

# Banner Welcome
echo -e "\033[1;32m"
echo " _______                 ____  ___      .__         .__  __   "
echo " \\      \\ _____    _____ \\   \\/  /_____ |  |   ____ |__|/  |_ "
echo " /   |   \\\\__  \\  /     \\ \\     /\\____ \\|  |  /  _ \\|  \\   __\\"
echo "/    |    \\/ __ \\|  Y Y  \\/     \\|  |_> >  |_(  <_> )  ||  |  "
echo "\\____|__  (____  /__|_|  /___/\\  \\   __/|____/\\____/|__||__|  "
echo "        \\/     \\/      \\/      \\_/__|                         "
echo -e "\033[0m"
echo "                Welcome to NamXploit!                "
echo "             Automated Subdomain Scanning Tool         "
echo

# Informasi Sosial Media
echo -e "\033[1;31mGitHub : Anam1602\033[0m"
echo -e "\033[1;31mLinkedIn : Khoirul Anam\033[0m"
echo

# Fungsi untuk memeriksa dan menginstal alat jika belum terinstal
install_if_missing() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Tool $1 tidak terinstal. Menginstal..."
        case "$1" in
            subfinder)
                go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
                ;;
            httpx)
                go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
                ;;
            amass)
                sudo apt install amass -y
                ;;
            katana)
                go install -v github.com/shenwei356/katana@latest
                ;;
            nuclei)
                go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
                ;;
            assetfinder)
                go install -v github.com/tomnomnom/assetfinder@latest
                ;;
            waybackurls)
                go install -v github.com/tomnomnom/waybackurls@latest
                ;;
            gau)
                go install -v github.com/lc/gau@latest
                ;;
            subjack)
                go install -v github.com/haccer/subjack@latest
                ;;
            nikto)
                sudo apt install nikto -y
                ;;
            httprobe)
                go install -v github.com/tomnomnom/httprobe@latest
                ;;
            *)
                echo "Tidak ada instruksi instalasi untuk $1. Silakan instal secara manual."
                exit 1
                ;;
        esac
    fi
}

# Memeriksa dan menginstal alat yang diperlukan
install_if_missing "subfinder"
install_if_missing "httpx"
install_if_missing "amass"
install_if_missing "katana"
install_if_missing "nuclei"
install_if_missing "assetfinder"
install_if_missing "waybackurls"
install_if_missing "gau"
install_if_missing "subjack"
install_if_missing "nikto"
install_if_missing "httprobe"

# Meminta input domain dari pengguna
read -p "Masukkan domain (contoh: example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "Domain tidak boleh kosong. Skrip dihentikan."
    exit 1
fi

# Menghilangkan ekstensi domain untuk nama folder
FOLDER_NAME=$(echo "$DOMAIN" | sed 's/\.[^.]*$//')

# Buat direktori untuk output
OUTPUT_DIR="$HOME/Tools/bugbounty/$FOLDER_NAME"
mkdir -p "$OUTPUT_DIR"

# Subdomain enumeration menggunakan subfinder
echo "[*] Menemukan subdomain untuk $DOMAIN..."
subfinder -d "$DOMAIN" -all -o "$OUTPUT_DIR/subdomains.txt" -silent

# Subdomain enumeration menggunakan amass
echo "[*] Menemukan subdomain dengan amass..."
amass enum -d "$DOMAIN" -active -o "$OUTPUT_DIR/amass_subdomains.txt"

# Gabungkan subdomain dari kedua output
cat "$OUTPUT_DIR/subdomains.txt" "$OUTPUT_DIR/amass_subdomains.txt" | sort -u > "$OUTPUT_DIR/all_subdomains.txt"

# Memeriksa status subdomain menggunakan httpx dengan User-Agent "Pentest Only"
echo "[*] Memeriksa status subdomain menggunakan httpx..."
httpx -l "$OUTPUT_DIR/all_subdomains.txt" -status-code -o "$OUTPUT_DIR/live_subdomains.txt" -threads 50 -timeout 10 -H "User-Agent: Pentest Only"

# Menggunakan katana untuk informasi tambahan (opsional)
echo "[*] Mengumpulkan informasi tambahan dengan katana..."
katana -d "$DOMAIN" -o "$OUTPUT_DIR/katana_output.txt" --timeout 10 --threads 50

# Menggunakan assetfinder untuk menemukan subdomain terkait
echo "[*] Menjalankan assetfinder..."
assetfinder --subs-only "$DOMAIN" | sort -u >> "$OUTPUT_DIR/all_subdomains.txt"

# Menggunakan waybackurls untuk mengambil URL yang pernah ada
echo "[*] Mengambil URL dari Wayback Machine..."
waybackurls "$DOMAIN" > "$OUTPUT_DIR/wayback_urls.txt"

# Menggunakan gau untuk mengambil semua URL
echo "[*] Mengambil semua URL dengan gau..."
gau "$DOMAIN" | sort -u >> "$OUTPUT_DIR/all_urls.txt"

# Memeriksa potensi pengambilalihan subdomain
echo "[*] Memeriksa pengambilalihan subdomain..."
subjack -w "$OUTPUT_DIR/all_subdomains.txt" -o "$OUTPUT_DIR/subjack_output.txt" -c "$HOME/subzy/fingerprints.json"

# Menjalankan nikto untuk pemindaian kerentanan dengan User-Agent "Pentest Only"
echo "[*] Menjalankan nikto..."
nikto -h "$DOMAIN" -output "$OUTPUT_DIR/nikto_output.txt" -user-agent "Pentest Only"

# Memeriksa status HTTP/HTTPS dengan httprobe
echo "[*] Memeriksa status HTTP/HTTPS dengan httprobe..."
httprobe < "$OUTPUT_DIR/all_subdomains.txt" > "$OUTPUT_DIR/http_status.txt"

# Menjalankan dirsearch untuk pemindaian direktori
echo "[*] Menjalankan dirsearch untuk pemindaian direktori..."
python3 /home/namxploit/dirsearch/dirsearch.py -u "http://$DOMAIN" -o "$OUTPUT_DIR/dirsearch_output.txt" -t 50 -H "User-Agent: Pentest Only"

# Filter output dari dirsearch untuk hasil 200 dan 403
echo "[*] Menyaring hasil dari dirsearch untuk status 200 dan 403..."
grep -E "200|403" "$OUTPUT_DIR/dirsearch_output.txt" > "$OUTPUT_DIR/dirsearch_filtered.txt"

# Menjalankan nuclei untuk pemindaian kerentanan
echo "[*] Menjalankan nuclei pada subdomain yang hidup..."
nuclei -l "$OUTPUT_DIR/live_subdomains.txt" -o "$OUTPUT_DIR/nuclei_output.txt" -t "$HOME/nuclei-templates" -timeout 5 -H "User-Agent: Pentest Only"

echo "[*] Proses selesai! Lihat output di direktori $OUTPUT_DIR."
