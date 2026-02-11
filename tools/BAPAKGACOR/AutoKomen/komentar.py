import requests
import time
import random
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from colorama import init, Fore, Style

# Inisialisasi colorama untuk output berwarna
init()

def post_komentar(url, nama, email, komentar_formatted, website, captcha_timeout=20):
    """
    Fungsi untuk memposting komentar dengan backlink ke form web menggunakan Selenium untuk CAPTCHA manual.
    
    Args:
    - url: URL form komentar
    - nama: Nama random
    - email: Email random
    - komentar_formatted: Komentar yang sudah diformat dengan backlink
    - website: URL website Anda
    - captcha_timeout: Waktu maksimum (detik) untuk menyelesaikan CAPTCHA secara manual
    
    Returns:
    - Tuple (status, pesan) di mana status adalah 'success' atau 'error'
    """
    firefox_options = Options()
    firefox_options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:129.0) Gecko/20100101 Firefox/129.0')
    firefox_options.add_argument('--disable-blink-features=AutomationControlled')
    firefox_options.set_preference('dom.webdriver.enabled', False)
    firefox_options.set_preference('useAutomationExtension', False)
    
    try:
        print(f"Mencoba membuka browser Firefox untuk {url}")
        driver = webdriver.Firefox(options=firefox_options)
    except Exception as e:
        error_msg = f"Gagal membuka browser untuk {url}: {str(e)}"
        print(Fore.RED + Style.BRIGHT + error_msg + Style.RESET_ALL)
        return 'error', error_msg
    
    try:
        print(f"Mengakses URL: {url}")
        driver.get(url)
        print("Menunggu elemen 'author'...")
        WebDriverWait(driver, 30).until(EC.presence_of_element_located((By.NAME, 'author')))
        
        print("Mengisi formulir...")
        driver.find_element(By.NAME, 'author').send_keys(nama)
        driver.find_element(By.NAME, 'email').send_keys(email)
        driver.find_element(By.NAME, 'comment').send_keys(komentar_formatted)
        driver.find_element(By.NAME, 'url').send_keys(website)
        
        # Check for CAPTCHA
        try:
            captcha = WebDriverWait(driver, 5).until(
                EC.presence_of_element_located((By.CLASS_NAME, 'g-recaptcha'))
            )
            print(f"CAPTCHA detected at {url}. Please solve it manually in the browser within {captcha_timeout} seconds.")
            print(f"Press Enter in the terminal after solving the CAPTCHA (or wait {captcha_timeout} seconds to skip).")
            
            start_time = time.time()
            input()
            if time.time() - start_time > captcha_timeout:
                error_msg = f"Timeout: CAPTCHA not solved within {captcha_timeout} seconds at {url}."
                print(Fore.RED + Style.BRIGHT + error_msg + Style.RESET_ALL)
                return 'error', error_msg
        except:
            print(f"No CAPTCHA detected at {url}. Proceeding to submit.")
        
        # Submit form
        try:
            print("Mencoba submit formulir...")
            submit_button = WebDriverWait(driver, 5).until(
                EC.element_to_be_clickable((By.NAME, 'submit'))
            )
            submit_button.click()
            time.sleep(2)
            success_msg = f"Sukses posting ke {url}!"
            print(Fore.GREEN + Style.BRIGHT + success_msg + Style.RESET_ALL)
            return 'success', success_msg
        except Exception as e:
            error_msg = f"Gagal submit form di {url}: {str(e)}"
            print(Fore.RED + Style.BRIGHT + error_msg + Style.RESET_ALL)
            return 'error', error_msg
            
    except Exception as e:
        error_msg = f"Error di {url}: {str(e)}"
        print(Fore.RED + Style.BRIGHT + error_msg + Style.RESET_ALL)
        return 'error', error_msg
    finally:
        print("Menutup browser...")
        time.sleep(5)
        driver.quit()

# Fungsi untuk baca list dari file
def baca_list_dari_file(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            items = [line.strip() for line in file if line.strip()]
        if not items:
            raise ValueError(f"File {file_path} kosong!")
        return items
    except FileNotFoundError:
        raise FileNotFoundError(f"File {file_path} tidak ditemukan!")

# Fungsi untuk simpan backlink yang berhasil ke file
def simpan_backlink_berhasil(url, pesan):
    with open('successful_backlinks.txt', 'a', encoding='utf-8') as f:
        f.write(f"{url}: {pesan}\n")

if __name__ == "__main__":
    # File paths
    urls_file = 'urls.txt'
    names_file = 'names.txt'
    emails_file = 'emails.txt'
    anchors_file = 'anchors.txt'
    comments_file = 'comments.txt'
    
    try:
        urls = baca_list_dari_file(urls_file)
        names = baca_list_dari_file(names_file)
        emails = baca_list_dari_file(emails_file)
        anchors = baca_list_dari_file(anchors_file)
        comments = baca_list_dari_file(comments_file)
    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error: {str(e)} Buat file-file txt yang diperlukan." + Style.RESET_ALL)
        exit()
    
    print(f"Ditemukan {len(urls)} URL, {len(names)} nama, {len(emails)} email, {len(anchors)} anchor, {len(comments)} komentar.")
    
    website = input("Masukkan URL website Anda (backlink target): ")
    
    # List untuk menyimpan backlink yang berhasil
    successful_backlinks = []
    
    for i, url in enumerate(urls, start=1):
        # Pilih random elemen
        nama_random = random.choice(names)
        email_random = random.choice(emails)
        anchor_random = random.choice(anchors)
        komentar_random = random.choice(comments)
        
        # Format backlink dan insert ke komentar
        backlink = f'<a href="{website}">{anchor_random}</a>'
        komentar_formatted = komentar_random.replace('{backlink}', backlink)
        
        print(f"\nPosting ke URL {i}/{len(urls)}: {url}")
        print(f"Detail random: Nama={nama_random}, Email={email_random}, Anchor={anchor_random}, Komentar={komentar_formatted}")
        
        status, hasil = post_komentar(url, nama_random, email_random, komentar_formatted, website)
        
        # Simpan backlink yang berhasil
        if status == 'success':
            successful_backlinks.append((url, hasil))
        
        if i < len(urls):  # Jeda hanya jika bukan URL terakhir
            print("Menunggu 10 detik sebelum post berikutnya...")
            time.sleep(10)
    
    # Simpan backlink yang berhasil ke file
    if successful_backlinks:
        print(Fore.GREEN + Style.BRIGHT + "\nMenyimpan backlink yang berhasil ke 'successful_backlinks.txt'..." + Style.RESET_ALL)
        for url, pesan in successful_backlinks:
            simpan_backlink_berhasil(url, pesan)
    
    print(Fore.GREEN + Style.BRIGHT + "\nSelesai memposting ke semua URL!" + Style.RESET_ALL)
