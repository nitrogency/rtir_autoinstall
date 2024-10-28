#!/bin/bash

PORT=8080

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

    sudo tee /etc/systemd/system/rt-server.service > /dev/null <<EOL
[Unit]
Description=RT Server
After=network.target

[Service]
Type=simple
User=www-data  
ExecStart=/opt/rt5/sbin/rt-server --port $PORT
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl enable rt-server
    sudo systemctl start rt-server

}

setup_dependencies && rt_install && rtir_install && start
