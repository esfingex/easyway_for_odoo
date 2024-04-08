#!/bin/bash

########################################
#                                      #
# Este script solo soporta versiones   #
# Ubuntu 18.04, 20.04, 22.04 (LTS)     #
# Iván Masías                          # 
# https://github.com/esfingex          #
#                                      #
########################################

#DEFINE
odoov=16.0			          #Versión odoo a instalar
release=$(lsb_release -cs)	          #Versión de SO (solo ubuntu)
pgsqlv=16	                          #Versión de PG (solo ubuntu)
duser=esfingex
source_list=/etc/apt/sources.list.d
gpgkey_path=/etc/apt/trusted.gpg.d

#Consulta arquitectura
if [ $(arch) == 'x86_64' ]; then archtype=arch=amd64; fi

function update_full(){
	apt-fast update -y
	apt-fast upgrade -y
	apt-fast autoremove -y
}

function requirements(){

	#echo "---> Instalando APT-FAST ... "
	add-apt-repository ppa:apt-fast/stable -y > /dev/null
	apt-get update -y > /dev/null
	DEBIAN_FRONTEND=noninteractive apt-get install -qq apt-fast -y > /dev/null

	echo "---> Actualizando Sistema ... "
	update_full > /dev/null

	#Instalación de repositorio multiverse y actualización de addons de forma automatica (ubuntu 18.04)
	if [ $release == 'bionic' ];
	then add-apt-repository multiverse > /dev/null
	fi

	#Agrega Repositorio de Python con versiones anteriores, 
	#para versiones superiores a ubuntu 20.04 (Solo LTS)
	systemos=('focal' 'jammy')
	
	for codename in ${systemos[@]}; do
	  if [ $release == $codename ];
	  then
	    add-apt-repository ppa:deadsnakes/ppa -y > /dev/null
	  fi
	done

	apt-get install gpg lsb-release aria2 -y > /dev/null
	echo ""

}

##wkhtmltopdf
#Descargar Archivos Base
#https://github.com/wkhtmltopdf/wkhtmltopdf/releases
function install_wkhtmltopdf(){
	apt-fast install xfonts-75dpi xfonts-base -y > /dev/null

	if [ $release == 'jammy' ];
	then
		echo "---> Instalando Paquetes ... "
		apt-get install wkhtmltopdf -y > /dev/null
	else
		url_get="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/"
		case $release in 
		'focal') wkhtmltox="wkhtmltox_0.12.5-1.focal_amd64.deb"
		;;
		'bionic') wkhtmltox="wkhtmltox_0.12.5-1.bionic_amd64.deb"
		;;
		esac
		echo "---> Descargando Paquetes... "
		wget -q $url_get$wkhtmltox
		echo "---> Instalando Paquetes ... "
		dpkg -i $wkhtmltox > /dev/null
		rm $wkhtmltox
	fi
	update_full > /dev/null
	echo ""
}

function install_postgres(){
	echo "---> PostgreSQL APT ... "
	text="deb [${archtype}] http://apt.postgresql.org/pub/repos/apt $release-pgdg main"
	echo $text >> $source_list/pgdg.list
	echo "---> PostgreSQL GPG Key ... "
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmour > $gpgkey_path/pgdg.gpg
	echo "---> Actualizando ... "
	update_full > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-get install libpq-dev postgresql-${pgsqlv} -y > /dev/null
	echo ""
}

#Odoo
function install_odoo(){
	echo "---> Odoo GPG Key ... "
	wget -qO- https://nightly.odoo.com/odoo.key | gpg --dearmour > $gpgkey_path/odoo.gpg
	echo "---> Odoo APT ... "
	text="deb [signed-by=${gpgkey_path}/odoo.gpg] http://nightly.odoo.com/${odoov}/nightly/deb/ ./"
	echo $text >> $source_list/odoo.list
	echo "---> Actualizando ... "
	update_full > /dev/null
	echo "Instalando Odoo"
	apt-get install odoo -y > /dev/null
	echo "---> Reiniciando ... "
	service odoo restart
	echo ""
}

function install_odoo_librery(){
	echo "Instalando Dependencias de Odoo ..."
	apt-get install python3.10-dev python3-distutils python3-pip -y > /dev/null
	su $duser -c "pip3 install --upgrade pip > /dev/null"
	su $duser -c "pip3 install pdf417gen paramiko cryptography==3.4.8 > /dev/null"
}

#function odoo_conf(){
#	#ODOO CONFIG
#	sudo touch /etc/odoo/odoo.conf
#	echo "admin_passwd = admin" | sudo tee --append /etc/odoo/odoo.conf
#}

function install_certbot(){
	echo "---> Instalando Cerbot ... "
	apt-get install -y certbot python3-certbot-nginx > /dev/null	
}

function gufw_basic(){
	echo "---> Reglas del Firewall (Básicas) ... "
	ufw default deny incoming
	ufw default allow outgoing
	iptables -A INPUT -p tcp --dport 8069 -j ACCEPT
	sudo ufw allow 8069/tcp
	sudo ufw allow 80/tcp
	sudo ufw allow 443/tcp
}

echo "################################################"
echo "Install OdooScript (Experimental)              #"
echo "for Easyway (https://github.com/esfingex)      #"
echo "################################################"
echo ""
#echo "Antes que Nada ... Lo escencial _"
#requirements
#echo "Instalando Librería wkhtmltopdf ..."
#install_wkhtmltopdf
#echo "Instalando PostgreSQL ..."
#install_postgres
#echo "Instalando Odoo ..."
#install_odoo
#echo "Instalando Librerías ..."
#install_odoo_librery
echo "Configurando Odoo ..."
#odoo_conf
#echo "Instalando Certbot ..."
install_certbot
#echo "Instalando Firewall ..."
#gufw_basic