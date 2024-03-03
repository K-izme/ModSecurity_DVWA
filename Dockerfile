FROM debian:10

RUN apt-get update && \
    apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    debconf-utils && \
    echo mariadb-server mysql-server/root_password password vulnerables | debconf-set-selections && \
    echo mariadb-server mysql-server/root_password_again password vulnerables | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    mariadb-server \
    php \
    php-mysql \
    php-pgsql \
    php-pear \
    php-gd \
    modsecurity-crs \
    curl \ 
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY php.ini /etc/php5/apache2/php.ini
COPY dvwa /var/www/html

COPY config.inc.php /var/www/html/config/

RUN chown www-data:www-data -R /var/www/html && \
    rm /var/www/html/index.html

RUN service mysql start && \
    sleep 3 && \
    mysql -uroot -pvulnerables -e "CREATE USER app@localhost IDENTIFIED BY 'vulnerables';CREATE DATABASE dvwa;GRANT ALL privileges ON dvwa.* TO 'app'@localhost;"


RUN cd /etc/modsecurity && cp modsecurity.conf-recommended modsecurity.conf
RUN cd /etc/modsecurity && sed -i 's/SecRuleEngine [^ ]*/SecRuleEngine On/'  modsecurity.conf
RUN cd /etc/modsecurity && mkdir custom
COPY modsec.conf /etc/modsecurity/custom/rules.conf
COPY lfi-os-files.data /etc/modsecurity/custom/lfi-os-files.data
COPY restricted-files.data /etc/modsecurity/custom/restricted-files.data
RUN echo "SecRuleEngine On\n\
SecRule ARGS \"<script|javascript|alert|<|>\" \"id:99999,deny,status:403,msg:'XSS detected, access forbidden.'\"\n\
SecRule ARGS \"@contains select\" \"id:100001,deny,status:403,msg:'SQL Injection detected, access forbidden.'\"\n\
SecRule ARGS \"@contains /etc/passwd\" \"id:100002,deny,status:403,msg:'Local File Inclusion detected, access forbidden.'\"" >> /etc/modsecurity/custom/rules.conf

RUN a2enmod security2
RUN sed -i 's/IncludeOptional \/usr\/share\/.*//g' /etc/apache2/mods-enabled/security2.conf
RUN sed -i 's/.*IncludeOptional.*/&\nIncludeOptional \/etc\/modsecurity\/custom\/\*.conf/' /etc/apache2/mods-enabled/security2.conf
EXPOSE 80

COPY main.sh /
ENTRYPOINT ["/main.sh"]
