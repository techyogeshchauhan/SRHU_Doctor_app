
import os
import re
import requests
from urllib.parse import urlparse
from bs4 import BeautifulSoup

URLS = [
    "https://share.google/ulyDahiNMwHewcnZh",
    "https://share.google/ZePIkNpwrgTTTIhXV",
    "https://www.slideshare.net/slideshow/quantitative-techniques-business-statistics-complete-book-mba-rtu-ca-suvidha-chaplot/289425580",
    "https://share.google/77tPwIgqCey2KY4Os",
    "https://www.slideshare.net/slideshow/brics-andtheglobaleconomy/43821236",
]

OUTPUT_DIR = "downloaded_pdfs"
os.makedirs(OUTPUT_DIR, exist_ok=True)

session = requests.Session()
session.headers["User-Agent"] = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
)


def safe_name(name):
    name = re.sub(r'[<>:"/\\|?*]+', "_", name)
    return name.strip(" .")[:150] or "document"


def download_pdf(url, index):
    print(f"\n[{index}] Checking: {url}")

    try:
        response = session.get(
            url, timeout=30, allow_redirects=True
        )
        response.raise_for_status()

        # Download only when the response is actually a PDF.
        if (
            response.content.startswith(b"%PDF-")
            and len(response.content) > 5
        ):
            filename = os.path.basename(
                urlparse(response.url).path
            ) or f"document_{index}.pdf"

            filename = safe_name(filename)
            if not filename.lower().endswith(".pdf"):
                filename += ".pdf"

            path = os.path.join(OUTPUT_DIR, filename)

            # Prevent overwriting an existing file.
            base, ext = os.path.splitext(path)
            counter = 2
            while os.path.exists(path):
                path = f"{base}_{counter}{ext}"
                counter += 1

            with open(path, "wb") as file:
                file.write(response.content)

            print(f"SUCCESS: {path}")
            return True

        # A web page is not the same as a PDF download.
        soup = BeautifulSoup(response.text, "html.parser")
        title = (
            soup.title.get_text(" ", strip=True)
            if soup.title else "PDF page"
        )

        print(f"Manual download required: {title}")
        print(f"Open: {response.url}")
        return response.url

    except requests.RequestException as error:
        print(f"ERROR: {error}")
        return url


manual_links = []

for index, url in enumerate(URLS, start=1):
    result = download_pdf(url, index)
    if result is not True:
        manual_links.append(result)

# Save pages that need manual downloading.
links_file = os.path.join(
    OUTPUT_DIR, "manual_download_links.txt"
)

with open(links_file, "w", encoding="utf-8") as file:
    file.write("\n".join(manual_links))

print("\nAll links processed.")
print(f"Output folder: {os.path.abspath(OUTPUT_DIR)}")
print(f"Manual links: {os.path.abspath(links_file)}")
