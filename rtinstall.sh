#!/bin/bash

setup_dependencies() {
    echo "Updating system packages & installing dependencies"
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y perl make git build-essential libssl-dev libexpat1-dev \
        libmysqlclient-dev libcrypt-ssleay-perl liblwp-protocol-https-perl \
        mariadb-server mariadb-client nginx
    

    sudo systemctl enable --now mariadb nginx
}

rt_install() {
    echo "Installing RT"
    curl -s https://api.github.com/repos/bestpractical/rt/releases/latest | grep ".tar.gz" | cut -d '"' -f 4 | wget -qi - -O rt.tar.gz
    mkdir rt && tar xf rt.tar.gz -C rt --strip-components 1
    rm rt.tar.gz
    cd rt

    ./configure
    make testdeps
    yes | sudo cpan install App::cpanminus
    sudo cpanm --notest HTML::FormatText HTML::TreeBuilder HTML::FormatText::WithLinks \
        HTML::FormatText::WithLinks::AndTables DBD::mysql LWP::Protocol::https \
        Parallel::ForkManager Parallel::Prefork CPAN::DistnameInfo App::FatPacker \
        Module::Pluggable Convert::Color Apache::Session Business::Hours CGI::Emulate::PSGI \
        CGI::PSGI CSS::Minifier::XS CSS::Squish Class::Accessor::Fast Crypt::Eksblowfish \
        DBIx::SearchBuilder Data::GUID Data::ICal Data::Page Date::Extract Date::Manip DateTime \
        DateTime::Format::Natural DateTime::Locale Devel::GlobalDestruction Devel::StackTrace \
        Email::Address Email::Address::List Encode::Detect::Detector Encode::HanExtra \
        File::ShareDir HTML::FormatExternal HTML::Gumbo HTML::Mason HTML::Mason::PSGIHandler \
        HTML::Quoted HTML::RewriteAttributes HTML::Scrubber IPC::Run3 JSON \
        JavaScript::Minifier::XS List::MoreUtils Locale::Maketext::Fuzzy Locale::Maketext::Lexicon \
        Log::Dispatch MIME::Entity MIME::Types Module::Path Module::Refresh Module::Runtime \
        Module::Versions::Report Moose MooseX::NonMoose MooseX::Role::Parameterized Mozilla::CA \
        Net::CIDR Net::IP Path::Dispatcher Plack Plack::Handler::Starlet Regexp::Common \
        Regexp::Common::net::CIDR Regexp::IPv6 Role::Basic Scope::Upper Sub::Exporter \
        Symbol::Global::Name Text::Password::Pronounceable Text::Quoted Text::Template \
        Text::WikiFormat Text::WordDiff Text::Wrapper Time::ParseDate Tree::Simple Web::Machine \
        XML::RSS namespace::autoclean File::Which GnuPG::Interface PerlIO::eol Crypt::X509 \
        String::ShellQuote || exit 1
    make testdeps
    sudo make install

    echo | sudo make initialize-database || exit 1
    echo "Installation successful."
}

rtir_install() {
    echo "Installing RTIR"
    curl -s https://api.github.com/repos/bestpractical/rtir/releases/latest | grep ".tar.gz" | cut -d '"' -f 4 | wget -qi - -O rtir.tar.gz
    mkdir rtir && tar xf rtir.tar.gz -C rtir --strip-components 1
    rm rtir.tar.gz
    cd rtir

    y | perl "Makefile.PL"
    sudo make install
    echo "Plugin('RT::IR');" | tee -a /opt/rt5/etc/RT_SiteConfig.pm
    echo | make initdb
    sudo systemctl restart nginx
    echo "Installation successful."
}

start() {

sudo apt install spawn-fcgi
    
cat << 'EOF' > /etc/nginx/sites-available/default
server {
        listen 80;
        server_name 127.0.0.1;
        access_log  /var/log/nginx/access.log;

        location / {
            client_max_body_size 100M;

            fastcgi_param  QUERY_STRING       $query_string;
            fastcgi_param  REQUEST_METHOD     $request_method;
            fastcgi_param  CONTENT_TYPE       $content_type;
            fastcgi_param  CONTENT_LENGTH     $content_length;

            fastcgi_param  SCRIPT_NAME        "";
            fastcgi_param  PATH_INFO          $uri;
            fastcgi_param  REQUEST_URI        $request_uri;
            fastcgi_param  DOCUMENT_URI       $document_uri;
            fastcgi_param  DOCUMENT_ROOT      $document_root;
            fastcgi_param  SERVER_PROTOCOL    $server_protocol;

            fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
            fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;

            fastcgi_param  REMOTE_ADDR        $remote_addr;
            fastcgi_param  REMOTE_PORT        $remote_port;
            fastcgi_param  SERVER_ADDR        $server_addr;
            fastcgi_param  SERVER_PORT        $server_port;
            fastcgi_param  SERVER_NAME        $server_name;
            fastcgi_pass 127.0.0.1:9000;
        }
    }

EOF

nginx -t
systemctl reload nginx

sudo tee /etc/systemd/system/rt-server.service > /dev/null <<EOF
[Unit]
Description=RT Server
After=network.target

[Service]
Type=simple
User=www-data  
ExecStart=/usr/bin/spawn-fcgi -n -f /opt/rt5/sbin/rt-server.fcgi -p 9000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable rt-server
sudo systemctl start rt-server

}

config_db() {

PASSWORD=$(openssl rand -base64 32)

sudo mysql_secure_installation <<EOF
N
N
Y
Y
Y
Y
EOF

sudo mysql -u root -e "ALTER USER 'rt_user'@'localhost' IDENTIFIED BY '$PASSWORD';"

echo "Set(\$DatabasePassword, \"$PASSWORD\");" | tee -a /opt/rt5/etc/RT_SiteConfig.pm > /dev/null
echo "Set(\$AutoLogoff, 60);" | tee -a /opt/rt5/etc/RT_SiteConfig.pm > /dev/null
echo "Set(\$WebSameSiteCookies, \"Secure\");" | tee -a /opt/rt5/etc/RT_SiteConfig.pm > /dev/null
echo "Set(\$MinimumPasswordLength, 8);" | tee -a /opt/rt5/etc/RT_SiteConfig.pm > /dev/null
}


setup_dependencies && rt_install && rtir_install && config_db && start
