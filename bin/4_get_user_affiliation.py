# encoding=utf8
# extract reduced_users companies

import yaml
from utils import *
from email_split import email_split
from world_popular_domains import popular_domains

stop_words = [
    "",
    "freelancing",
    "freelance web developer",
    "freelance developer",
    "freelancer",
    "freelance",
    "free",
    "company",
    "school",
    "web developer",
    "independent",
    "independent contractor",
    "independent consultant",
    "independent developer",
    "remove",
    "student",
    "n/a",
    "na",
    "no",
    "-",
    "self",
    "myself",
    "personal",
    "home",
    "japan",
    "china",
    "shanghai"
    "null",
    "none",
    "self-employed",
    "self employed",
    "private",
    "individual",
    "unknown",
    "me",
    "no company",
    "consultant",
    "undefined",
    "developer",
    "secret",
    "...",
    "xxx"
]

stop_words_email = [
    # mail related stop words
    "github",
    "yahoo",
    "yandex",
    "gmail",
    "139",
    "qq"
]

university_names = {
    "cmu": "carnegie mellon university",
    "thu": "tsinghua university",
    "stanford": "stanford university",
    "zju": "zhejiang university",
    "uw": "university of washington",
    "uc berkeley": "university of california, berkeley",
    "university of california berkeley": "university of california, berkeley",
    "pku": "peking university",
    "bupt": "beijing university of posts and telecommunications",
    "mit": "massachusetts institute of technology",
    "uestc": "university of electronic science and technology of china",
    "sjtu": "shanghai jiaotong university",
    "shanghai jiao tong university": "shanghai jiaotong university",
    "hust": "huazhong university of science and technology",
    "nju": "nanjing university",
    "ustc": "university of science and technology of china",
    "nyu": "new york university",
    "epfl": "epfl",
    "sysu": "sun yat-sen university",
    "mipt": "moscow institute of physics and technology",
    "whu": "otto beisheim school of management",
    "tu delft": "delft university of technology",
    "tu dersden": "dresden university of technology",
    "general assembly": "general assembly",
    "neu": "northeastern university",
    "uiuc": "university of illinois at urbana-champaign",
    "cuhk": "the chinese university of hong kong",
    "ubc": "the university of british columbia",
    "ucsf": "university of california, san francisco",
    "nus": "national university of singapore",
    "szu": "shenzhen university",
    "zjut": "zhejiang university of technology",
    "epitech": "european institute of technology",
    "uc davis": "university of california, davis",
    "university of california davis": "university of california, davis",
    "uc san diego": "university of california, san diego",
    "university of california san diego": "university of california, san diego",
    "uc irvine": "university of california, irvine",
    "university of california irvine": "university of california, irvine",
    "ecnu": "east china normal university",
    "flatiron school": "flatiron school",
    "hdu": "hangzhou dianzi university",
    "xjtu": "xi'an jiaotong university",
    "cqupt": "chongqing university of posts and telecommunications",
    "hkust": "hong kong university of science and technology",
    "ucla": "university of california, los angeles",
    "university of california los angeles": "university of california, los angeles",
    "scut": "south china university of technology",
    "hit": "harbin institute of technology",
    "georgia tech": "georgia institute of technology",
    "buaa": "beihang university",
    "ucl": "university college london",
    "iit bombay": "indian institutes of technology bombay",
    "iit kharagpur": "indian institutes of technology kharagpur",
    "iit roorkee": "indian institutes of technology roorkee",
    "iit": "indian institutes of technology",
    "iiit": "indian institutes of information technology",
    "eth zurich": "eth zurich",
    "kaist": "korea advanced institute of science and technology",
    "seu": "southeast university",
    "virginia tech": "virginia polytechnic institute and state university",


    "university of colorado boulder": "university of colorado at boulder",
    "washington university in st. louis": "washington university, saint louis"
}

company_name_startswiths = [
    "@"
]

company_name_endswiths = [
    "!",
    ", inc.",
    "-inc",
    " inc.",
    " inc",
    " intl.",
    " intl",
    " ltd.",
    " ltd",
    " group",
    " labs",
    " systems",
    " software",
    ".com",
    ".org",
    " corporation",
    " se",
    " research",
    " technologies",
    " lp",
    " l.p.",
    " corp.",
    " co., ltd.",
    " pty ltd."
]

company_alias = {
    "qihoo": "360",
    "taobao": "alibaba",
    "alibaba cloud": "alibaba",
    "阿里巴巴": "alibaba",
    "alipay": "alibaba",
    "redhat": "red hat",
    "aws": "amazon",
    "amazon web services": "amazon",
    "tcs": "tata consultancy services",
    "dell ewc": "ewc",
    "cognizant technology solutions": "cognizant",
    "suse linux gmbh": "suse",
    "百度": "baidu",
    "fb": "facebook"
}

email_replace_strs = {
    "[at]": "@",
    "[dot]": ".",
    "(at)": "@",
    "(dot)": ".",
    "AT": "@",
    "DOT": ".",
    " at ": "@",
    " dot ": ".",
    "_at_": "@",
    "-at-": "@",
    "_dot_": ".",
    "-dot-": ".",
    "((at))": "@",
    "((dot))": "."
}

def read_world_uni_domains():
    result = {}
    uni_domain_list = json.loads(readFile("world_universities_and_domains.json"))
    for item in uni_domain_list:
       domains = item["domains"]
       name = item["name"]
       for domain in domains:
           result[domain] = name
    return result

def changeCompanyName(company):
    if company is None or company.lower() in stop_words:
        return None
    else:
        company = company.lower().strip()

    if university_names.has_key(company):
        company = university_names[company]

    # company names
    for start in company_name_startswiths:
        if company.startswith(start):
            company = company[len(start):]

    for end in company_name_endswiths:
        if company.endswith(end):
            company = company[:len(company) - len(end)]

    company = company.strip()
    if company == "":
        return None

    # alias
    if company_alias.has_key(company):
        company = company_alias[company]

    return company

def changeDomainName(domain):

    if domain is None:
        return None
    
    # get the first part of the domain
    if ".com" in domain:
        domain = domain[0:domain.find(".com")]
        company = domain.split(".")[-1]
    elif ".org" in domain:
        domain = domain[0:domain.find(".org")]
        company = domain.split(".")[-1]
    else:
        return None

    for end in company_name_endswiths:
        if company.endswith(end):
            company = company[:len(company) - len(end)]

    company = company.strip()
    if company == "":
        return None

    # alias
    if company_alias.has_key(company):
        company = company_alias[company]

    return company

def getDomain(email):
    if email is None or email.strip() == "":
        return None

    # change sth (special characters)
    for o, n in email_replace_strs.items():
        email = email.replace(o, n)
    email = email.replace(r"\s", "").lower()

    email_splits = email_split(email.strip())
    domain = email_splits.domain
    if domain == "":
        return None
    return domain

f = open('config.yaml', 'r')
config = yaml.load(f.read(), Loader=yaml.BaseLoader)

db = connectMysqlDB(config)
cur = db.cursor()

uni_domain_dict = read_world_uni_domains()

# first create result table
create_table_sql = "CREATE TABLE `reduced_users_company` (" \
              "`id` int(11) NOT NULL AUTO_INCREMENT, " \
              "`user_id` int(11) NOT NULL, " \
              "`login` varchar(255) NOT NULL, " \
              "`name` varchar(255) DEFAULT NULL, " \
              "`type` varchar(255) DEFAULT NULL, " \
              "PRIMARY KEY (`id`), " \
              "KEY `user_id` (`user_id`), " \
              "KEY `login` (`login`)" \
              ") ENGINE=InnoDB DEFAULT CHARSET=utf8;"
try:
    cur.execute(create_table_sql)
except Exception as e:
    if e.args[0] == 1050:
        pass
    else:
        print e.message
        sys.exit(-1)



# read all the user login and ids
user_id_dict = {}
cur.execute("select id, login from reduced_users")
items = cur.fetchall()
for item in items:
    user_id = item[0]
    login = item[1]
    user_id_dict[login] = user_id


user_company_dict = {} # record the company of users (key:user_login; value:(company_name,type,user_id))
cur.execute("select id, login, company from reduced_users")
users = cur.fetchall()
for user in users:
    user_id = user[0]
    login = user[1]
    company = user[2]
    company = changeCompanyName(company)
    print "handling user: %d" % (user_id)

    if company is not None and company != "":
        if "university" in company or \
            "institute" in company or \
            "college" in company or \
            "school" in company or \
            company in university_names.values():
            type = "university"
        else:
            type = "company"
        
        user_company_dict[login] = (company, type, user_id)

    


# handle email
user_domain_dict = {} # record the domain of each user
domains = {}
cur.execute("select login, email from reduced_users_email")
emails = cur.fetchall()
for email in emails:
    login = email[0]
    print "handling user: %s" % (login)
    domain = getDomain(email[1])
    if domain is None or domain == "":
        continue

    if domain in popular_domains:
        continue
    
    company = uni_domain_dict.get(domain, None) # get the name if it's a university

    type = None
    if company is not None:
        company = company.lower()
        type = "university"
    
    else:
        company = changeDomainName(domain)
        type = "company"

    if company is None or company in stop_words_email:
        continue
    domains.setdefault(company, 0)
    domains[company] += 1

    user_domain_dict[login] = (company, type)



# firstly use the company in user_company_dict, if not exists use user_domain_dict
for login, value in user_domain_dict.items():
    if user_company_dict.has_key(login) == True:
        pass
    else:
        user_id = user_id_dict[login]
        user_company_dict[login] = (value[0], value[1], user_id)

# insert into database
for login, value in user_company_dict.items():
    cur.execute("insert into reduced_users_company (user_id, login, name, type) values (%s, %s, %s, %s)", (value[2], login, value[0], value[1]))
print "finish"