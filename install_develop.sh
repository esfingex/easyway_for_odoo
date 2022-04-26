#!/bin/bash

########################################
#                                      #
# Este script solo soporta versiones   #
# Ubuntu 18.04, 20.04(LTS)             #
# 22.04 es experimental aún            #
# Iván Masías                          # 
# https://github.com/esfingex          #
########################################

#DEFINE
odoov=14			#Versión odoo a instalar
release=$(lsb_release -cs)	#Versión de SO (solo ubuntu)
duser=esfingex
source_list=/etc/apt/sources.list.d
gpgkey_path=/etc/apt/trusted.gpg.d

function update(){
	apt-get update -y
	apt-get upgrade -y
	apt-get autoremove -y
}

function requirements(){
	
	update > /dev/null

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

	#FIX Librería wkhtmltopdf en jammy para libssl1.1 (OpenSSL)
	if [ $release == 'jammy' ]; then
		text="deb [${archtype}] deb http://security.ubuntu.com/ubuntu impish-security main"
		echo $text >> /etc/apt/sources.list.d/impish.list
		apt install libssl1.1 -y > /dev/null
	fi
	apt-get install gpg lsb-release -y > /dev/null
	echo ""

}


#Consulta arquitectura
if [ $(arch) == 'x86_64' ]; then archtype=arch=amd64; fi

function install_postgres(){
	echo "---> PostgreSQL GPG Key ... "
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmour > pgdg.gpg
	mv pgdg.gpg $gpgkey_path/pgdg.gpg
	pgpkey_path=signed-by=$gpgkey_path/pgdg.gpg
	echo "---> PostgreSQL APT ... "
	text="deb [${archtype} ${pgpkey_path}] http://apt.postgresql.org/pub/repos/apt $release-pgdg main"
	echo $text >> $source_list/pgdg.list
	echo "---> Actualizando ... "
	update > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-get install libpq-dev postgresql -y > /dev/null
	echo ""
}

function install_pgadmin(){
	text="deb [${archtype}] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$release pgadmin4 main"
	echo $text >> /etc/apt/sources.list.d/pgadmin4.list
	echo "---> pgAdmin4 Key ... "
	wget --quiet -O - https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo apt-key add -
	echo "---> Actualizando ... "
	update > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-get install pgadmin4-desktop -y > /dev/null
	echo ""
}

##wkhtmltopdf
#Descargar Archivos Base
#https://github.com/wkhtmltopdf/wkhtmltopdf/releases
function install_wkhtmltopdf(){
	apt-get install xfonts-75dpi xfonts-base -y > /dev/null
	url_get="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/"
	case $release in 
	'focal') wkhtmltox="wkhtmltox_0.12.5-1.focal_amd64.deb"
	;;
	'bionic') wkhtmltox="wkhtmltox_0.12.5-1.bionic_amd64.deb"
	;;
	'jammy') wkhtmltox="wkhtmltox_0.12.5-1.bionic_amd64.deb"
	;;
	esac

	wget -q $url_get$wkhtmltox
	echo "---> Instalando Paquetes ... "
	dpkg -i $wkhtmltox > /dev/null
	rm $wkhtmltox
	update > /dev/null
	echo ""
}

function install_gith_desk(){
	text="deb [${archtype}] https://packagecloud.io/shiftkey/desktop/any/ any main"
	echo $text >> /etc/apt/sources.list.d/shiftkey-desktop.list
	echo "---> Github Desktop Key ... "
	wget -qO- https://packagecloud.io/shiftkey/desktop/gpgkey | sudo apt-key add -
	echo "---> Actualizando ... "
	update > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-get install github-desktop -y > /dev/null
	echo ""
}

function install_vscode(){
	text="deb [${archtype}] https://packages.microsoft.com/repos/code stable main"
	echo $text >> /etc/apt/sources.list.d/vscode.list
	echo "---> VScode Key ... "
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
	echo "---> Actualizando ... "
	update > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-get install apt-transport-https code -y > /dev/null
	echo ""
}

function install_odoo_dev(){
	echo "Instalando Dependencias de Odoo ..."
	apt-get install  git libxml2-dev libjpeg-dev libsasl2-dev libldap2-dev libssl-dev zlib1g-dev libxslt1-dev libldap2-dev python3.8 python3.8-dev python3-pip python3-virtualenv -y > /dev/null
	
	#Repara el error de path que ocurre en Ubuntu sobre pip
	su $duser -c "export PATH=$PATH:/home/$duser/.local/bin"	
	su $duser -c "pip install --upgrade pip > /dev/null"
	su $duser -c "pip3 install --upgrade pip > /dev/null"

	#Descarga odoo
	echo "---> Descarga Odoo SRC ..."
	wget -q https://nightly.odoo.com/${odoov}.0/nightly/src/odoo_${odoov}.0.latest.tar.gz		#Descarga
	
	echo "---> Descomprimiendo ..."
	tar -xf odoo_${odoov}.0.latest.tar.gz > /dev/null											#Descomprime
	mv odoo-${odoov}.* odoo																		#Cambia el nombre

	echo "---> Estructura Directorios ..."
	mkdir -p /opt/odoo/odoo${odoov}/
	cp -R odoo/ /opt/odoo/odoo${odoov}															#Copia a directorio
	chmod 777 -R /opt/odoo																		#Asignación de permisos
	rm odoo_${odoov}.0.latest.tar.gz															#Borra el temp
	rm -R odoo
}

function config_odoo_src(){
	echo "Configurando Odoo ..."
	echo "---> Configurando SRC ..."
	mv /opt/odoo/odoo${odoov}/odoo/setup/odoo /opt/odoo/odoo${odoov}/odoo/odoo-bin				#Copia ejecutable python en dictorio principal
	rm -R /opt/odoo/odoo${odoov}/odoo/setup
	rm -R /opt/odoo/odoo${odoov}/odoo/odoo.egg-info
	rm /opt/odoo/odoo${odoov}/odoo/setup.cfg
	rm /opt/odoo/odoo${odoov}/odoo/setup.py
	rm /opt/odoo/odoo${odoov}/odoo/PKG-INFO
}

function config_odoo_env(){
	#Instalacion Enviroments
	echo "---> Creando Enviroments ..."
	mkdir /opt/odoo/venv
	virtualenv -p /usr/bin/python3.8 /opt/odoo/venv/odoo${odoov} > /dev/null
	source /opt/odoo/venv/odoo${odoov}/bin/activate
	pip install pip --upgrade > /dev/null
	echo "---> Instalando Dependencias Python ..."
	pip install -r /opt/odoo/odoo${odoov}/odoo/requirements.txt > /dev/null
	echo "---> Creando Workspace para VScode ..."
	mkdir -p /home/$duser/workspace/odoovs
	echo ""
}

echo "############################################"
echo "Install OdooScript Development             #"
echo "for Easyway (https://github.com/esfingex)  #"
echo "############################################"
echo ""
echo "Antes que Nada ... Lo escencial *_*"
#requirements
echo "Instalando Librería wkhtmltopdf ..."
#install_wkhtmltopdf
echo "Instalando PostgreSQL ..."
#install_postgres
echo "Instalando pgAdmin4 ..."
#install_pgadmin
echo "Instalando VScode ..."
#install_vscode
echo "Instalando Github Desktop ..."
#install_gith_desk
echo "Install Odoo ..."
#install_odoo_dev
#config_odoo_src
config_odoo_env
echo "Actualizando SO ..."
#update > /dev/null

echo "Instalación Finalizada Enjoy 3:)"
