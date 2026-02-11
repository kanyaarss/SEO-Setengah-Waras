import requests
from bs4 import BeautifulSoup
from colorama import init, Fore, Style
import time

# Inisialisasi colorama untuk mendukung warna di konsol
init()

# Watermark
WATERMARK = "https://t.me/bapakgacor"

def reverse_ip_lookup(ip):
    print(f"{Fore.CYAN}Memproses IP: {ip}{Style.RESET_ALL}")
    try:
        # URL RapidDNS untuk reverse IP lookup
        url = f"https://rapiddns.io/sameip/{ip}?full=1#result"
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()

        # Parsing halaman dengan BeautifulSoup
        soup = BeautifulSoup(response.text, 'html.parser')
        domains = []
        
        # Mencari tabel hasil
        table = soup.find('table', {'id': 'table'})
        if table:
            rows = table.find_all('tr')[1:]  # Lewati header tabel
            for row in rows:
                cols = row.find_all('td')
                if len(cols) > 0:
                    domain = cols[0].text.strip()
                    if domain:
                        domains.append(domain)
        
        if domains:
            print(f"{Fore.GREEN}  Ditemukan domain: {', '.join(domains)}{Style.RESET_ALL}")
            return domains
        else:
            print(f"{Fore.YELLOW}  Tidak ditemukan domain{Style.RESET_ALL}")
            return []
    except Exception as e:
        print(f"{Fore.RED}  Error: {str(e)}{Style.RESET_ALL}")
        return []

def process_ip_file(input_file, output_file):
    # Menampilkan watermark
    print(f"{Fore.MAGENTA}{'-' * 50}{Style.RESET_ALL}")
    print(f"{Fore.MAGENTA}Reverse IP Lookup Tool by {WATERMARK}{Style.RESET_ALL}")
    print(f"{Fore.MAGENTA}{'-' * 50}{Style.RESET_ALL}")

    # Membaca file input
    try:
        with open(input_file, 'r') as f:
            ip_list = [line.strip() for line in f if line.strip()]
        print(f"{Fore.BLUE}Total IP yang akan diproses: {len(ip_list)}{Style.RESET_ALL}")
    except FileNotFoundError:
        print(f"{Fore.RED}File input tidak ditemukan{Style.RESET_ALL}")
        return "File input tidak ditemukan"
    except Exception as e:
        print(f"{Fore.RED}Error membaca file: {str(e)}{Style.RESET_ALL}")
        return f"Error membaca file: {str(e)}"

    # Melakukan reverse lookup untuk setiap IP
    results = []
    for ip in ip_list:
        domains = reverse_ip_lookup(ip)
        results.extend(domains)
        time.sleep(0.5)  # Jeda untuk mencegah pemblokiran oleh RapidDNS

    # Menyimpan hasil ke file output (hanya nama domain per baris)
    try:
        with open(output_file, 'w') as f:
            for domain in results:
                f.write(f"{domain}\n")
        print(f"{Fore.GREEN}Hasil telah disimpan ke {output_file}{Style.RESET_ALL}")
    except Exception as e:
        print(f"{Fore.RED}Error menyimpan file: {str(e)}{Style.RESET_ALL}")
        return f"Error menyimpan file: {str(e)}"

    # Menampilkan watermark di akhir
    print(f"{Fore.MAGENTA}{'-' * 50}{Style.RESET_ALL}")
    print(f"{Fore.MAGENTA}Powered by {WATERMARK}{Style.RESET_ALL}")
    print(f"{Fore.MAGENTA}{'-' * 50}{Style.RESET_ALL}")
    
    return f"Hasil telah disimpan ke {output_file}"

# Menjalankan fungsi dengan file input dan output
if __name__ == "__main__":
    input_file = "ip.txt"
    output_file = "hasil-revip.txt"
    result = process_ip_file(input_file, output_file)
    print(f"{Fore.BLUE}{result}{Style.RESET_ALL}")
