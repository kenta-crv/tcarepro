#!/usr/bin/env python3
import sys
from extract_company_info import extract_company_info, get_url, get_inquiry_url_from_url, get_industry, get_genre_from_url

def main():
    args = sys.argv[1:]
    print(args[0])
    print(args[1])
    print(args[2])
    print(args[3])
    
    text, refs = extract_company_info(args[0], args[1])
    url = get_url(refs)
    inqiry_url = get_inquiry_url_from_url(url)
    indsutry = get_industry(url, args[2])
    genre = get_genre_from_url(url, args[3])
    print(indsutry)
    print(text)
    print(f"URL: {url}")
    print(inqiry_url)
    print(genre)


if __name__ == "__main__":
    main()
