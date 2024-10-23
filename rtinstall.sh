setup_dependencies() {
    echo "Updating system packages & installing dependencies"
    sudo apt update -y
    sudo apt upgrade -y

    sudo apt install perl -y
    sudo apt install make -y

    sudo apt install git -y

    sudo apt install build-essential libssl-dev libexpat1-dev libmysqlclient-dev libcrypt-ssleay-perl liblwp-protocol-https-perl -y

    sudo apt install mariadb-server mariadb-client -y
    sudo systemctl start mariadb.service

    sudo apt install nginx -y
    sudo systemctl start nginx.service
}

rt_install() {
    echo "Installing RT"
    curl -s https://api.github.com/repos/bestpractical/rt/releases/latest | grep ".tar.gz" | cut -d '"' -f 4 | wget -qi - -O rt.tar.gz
    echo "Downloaded"
    mkdir rt && tar xf rt.tar.gz -C rt --strip-components 1
    rm rt.tar.gz
    cd rt

    ./configure
    echo "Configure"
    make testdeps
    sudo cpan install HTML::FormatText HTML::TreeBuilder HTML::FormatText::WithLinks HTML::FormatText::WithLinks::AndTables DBD::mysql LWP::Protocol::https Parallel::ForkManager Parallel:Prefork CPAN::DistnameInfo App::FatPacker 
    sudo cpan install -fi Module::Pluggable Convert::Color
    PERL_MM_OPT="skip-test" PERL_MM_USE_DEFAULT=1 | sudo make fixdeps
    make testdeps
    sudo make install

    echo | sudo make initialize-database
    sudo /opt/rt5/sbin/rt-server
    echo "Installation successful. RT is running."
}

rtir_install() {
    cd ..
    echo "Installing RTIR"
    curl -s https://api.github.com/repos/bestpractical/rtir/releases/latest | grep ".tar.gz" | cut -d '"' -f 4 | wget -qi - -O rtir.tar.gz
    mkdir rtir && tar xf rtir.tar.gz -C rtir --strip-components 1
    rm rtir.tar.gz
    cd rtir

    y | sudo perl "Makefile.PL"
    sudo make install
    echo "Plugin('RT::IR');" | sudo tee -a /opt/rt5/etc/RT_SiteConfig.pm
    echo | sudo make initdb
    sudo systemctl restart nginx
    sudo /opt/rt5/sbin/rt-server
    echo "Installation successful. RTIR is running."
}

setup_dependencies
rt_install
rtir_install
