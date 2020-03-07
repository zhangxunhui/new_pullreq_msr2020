# encoding=utf8
import sys
import yaml
import MySQLdb
import urllib2
import json
from pymongo import MongoClient
import os

reload(sys)
sys.setdefaultencoding('utf8')

import csv

def readFile(filepath):
    f = open(filepath, "r")
    return f.read()


def writeFile(filepath, content):
    f = open(filepath, "w")
    f.write(content)
    f.close()


def writeCSV(filepath, contentList):
    with open(filepath, mode='w') as f:
        f_writer = csv.writer(f, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)

        for content in contentList:
            f_writer.writerow(content)


def readCSV(filepath):
    result = []
    with open(filepath) as f:
        csv_reader = csv.reader(f, delimiter=',')
        for row in csv_reader:
            result.append(row)
    return result


def connectMysqlDB(config, autocommit = True):

    db = MySQLdb.connect(host=config['mysql']['host'],
                         user=config['mysql']['user'],
                         passwd=config['mysql']['passwd'],
                         db=config['mysql']['db'],

                         local_infile=1,
                         use_unicode=True,
                         charset='utf8mb4',

                         sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION',

                         autocommit=autocommit)
    return db

def connectMongoDB(config):
    conn_url = "mongodb://" + config['mongo']['username'] + ":" + \
               config['mongo']['password'] + "@" + config['mongo']['host'] + ":" + config['mongo']['port']
    client = MongoClient(conn_url, readPreference='secondaryPreferred')
    mongodb = client[config['mongo']['db']]
    return client, mongodb


# read all the files in the folder (with/without suffix)
def get_files(dirpath, suffix = None):
    result = []
    files_paths = os.listdir(dirpath)
    if suffix is not None:
        result = [f for f in files_paths if f.endswith(suffix)]
    else:
        result = files_paths
    return result