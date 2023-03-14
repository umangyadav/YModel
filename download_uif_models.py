import requests
import wget
import re
import os
from bs4 import BeautifulSoup
from zipfile import ZipFile
import tarfile

url = 'http://mklnxpgk.amd.com/ModelZoo/UIF/1.1-release-migraphx/'
reqs = requests.get(url, allow_redirects=True)
soup = BeautifulSoup(reqs.text, 'html.parser')
curr_dir = os.getcwd()
dest_path = os.path.join(curr_dir, "YModelTesting")

if not os.path.exists(dest_path):
    os.makedirs(dest_path, exist_ok=True)

urls = []
for link in soup.find_all('a'):
    file_name = str(link.get('href'))
    if (file_name.startswith("tf") or file_name.startswith("pt")):
        if (not re.search("MI100", file_name)
                and not re.search("MI210", file_name)
                and not re.search("M100", file_name)
                and not re.search("M210", file_name)):
            print("\n Downloading now : ", file_name)
            file_url = url + '/' + file_name
            wget.download(file_url, dest_path)
            file_path = os.path.join(dest_path, file_name)
            if file_name.endswith(".zip"):
                try:
                    with ZipFile(file_path, 'r') as zObject:
                        zObject.extractall(dest_path)
                except:
                    print("\n Bad file detected :", file_name)
            elif file_name.endswith(".tar") or file_name.endswith(".tar.gz"):
                try:
                    tObject = tarfile.open(file_path)
                    tObject.extractall(path=dest_path)
                    tObject.close()
                except:
                    print("\n Bad file detected: ", file_name)
            # delete .zip/.tar files after download
            os.remove(file_path)
    else:
        print("\nSkipping downloading :", file_name)

print("\nFinished Downloading and extracting model files.")