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
odoov=14			                  #Versión odoo a instalar
release=$(lsb_release -cs)	          #Versión de SO (solo ubuntu)
pgsqlv=14	                          #Versión de PG (solo ubuntu)
duser=esfingex
source_list=/etc/apt/sources.list.d
gpgkey_path=/etc/apt/trusted.gpg.d

function update_full(){
	apt-fast update -y
	apt-fast upgrade -y
	apt-fast autoremove -y
}

function requirements(){

	echo "---> Instalando APT-FAST ... "
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

#Consulta arquitectura
if [ $(arch) == 'x86_64' ]; then archtype=arch=amd64; fi

function install_postgres(){
	echo "---> PostgreSQL APT ... "
	text="deb [${archtype}] http://apt.postgresql.org/pub/repos/apt $release-pgdg main"
	echo $text >> $source_list/pgdg.list
	echo "---> PostgreSQL GPG Key ... "
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmour > $gpgkey_path/pgdg.gpg
	echo "---> Actualizando ... "
	update_full > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-fast install libpq-dev postgresql-${pgsqlv} -y > /dev/null
	echo ""
}

function install_pgadmin(){
	echo "---> PGadmin APT ... "
	text="deb [${archtype}] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$release pgadmin4 main"
	echo $text >> $source_list/pgadmin4.list
	echo "---> pgAdmin4 Key ... "
	wget --quiet -O - https://www.pgadmin.org/static/packages_pgadmin_org.pub | gpg --dearmour > $gpgkey_path/pgadmin4.gpg
	echo "---> Actualizando ... "
	update_full > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-fast install pgadmin4-desktop -y > /dev/null
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
		apt-fast install wkhtmltopdf -y > /dev/null
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

function download_odoo_ver(){

	#Descarga odoo
	echo "---> Descarga Odoo SRC ..."
	aria2c -x2 --quiet=true https://nightly.odoo.com/${odoov}.0/nightly/src/odoo_${odoov}.0.latest.tar.gz > /dev/null	#Descarga
	
	echo "---> Descomprimiendo ..."
	tar -xf odoo_${odoov}.0.latest.tar.gz > /dev/null														#Descomprime
	mv odoo-${odoov}.* odoo																					#Cambia el nombre

	echo "---> Estructura Directorios ..."
	mkdir -p /opt/odoo/odoo${odoov}/
	cp -R odoo/ /opt/odoo/odoo${odoov}																		#Copia a directorio
	chmod 777 -R /opt/odoo																					#Asignación de permisos
	rm odoo_${odoov}.0.latest.tar.gz																		#Borra el temp
	rm -R odoo

}

function install_odoo_dev(){

	#Esta función permite agregar más versatilidad a la instalación de librerias adicionales
	#Falta diferenciar los paquetes entre las diferentes versiones de odoo, según la 14, 15, etc

	echo "Instalando Dependencias de Odoo ..."
	apt-fast install git libxml2-dev libjpeg-dev libsasl2-dev libldap2-dev libssl-dev zlib1g-dev \
		libxslt1-dev libldap2-dev python3.9 python3.9-dev python3.9-distutils python3-pip python3-virtualenv -y > /dev/null
	
	#Repara el error de path que ocurre en Ubuntu sobre pip
	su $duser -c "export PATH=$PATH:/home/$duser/.local/bin"	
	su $duser -c "pip install --upgrade pip > /dev/null"
	su $duser -c "pip3 install --upgrade pip > /dev/null"

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
	virtualenv -p /usr/bin/python3.9 /opt/odoo/venv/odoo${odoov} > /dev/null
	chmod 777 -R /opt/odoo/venv/odoo${odoov}
	source /opt/odoo/venv/odoo${odoov}/bin/activate
	pip install pip --upgrade > /dev/null
	echo "---> Instalando Dependencias Python ..."
	pip install -r /opt/odoo/odoo${odoov}/odoo/requirements.txt > /dev/null
	echo "---> Creando Workspace para VScode ..."
	mkdir -p /home/$duser/workspace/odoo${odoov}
	echo "---> Copiando Archivos de Configuración ..."
	mv odoovs/{.,}* /home/$duser/workspace/odoo${odoov}
	chmod 777 -R /home/$duser/workspace/odoo${odoov}
	ln -s /opt/odoo/odoo${odoov}/odoo/ /home/esfingex/workspace/odoo${odoov}/
	echo ""
}

#Herramientas de trabajo
function easyway_for_ubuntu(){
	echo "---> Descargando Instaladores ... "
	git clone https://github.com/esfingex/easyway_for_ubuntu.git > /dev/null
	chmod 777 -R easyway_for_ubuntu
	
	echo "---> Instalando Software ... "
	./easyway_for_ubuntu/vs_code.sh
	./easyway_for_ubuntu/install_github_desk.sh
	./easyway_for_ubuntu/install_wine.sh
	#Opcional
	#./easyway_for_ubuntu/install_wpsoffice.sh
	#./easyway_for_ubuntu/vivaldi_browser.sh
}

function gufw_basic(){
	echo "---> Reglas del Firewall (Básicas) ... "
	ufw default deny incoming
	ufw default allow outgoing
	iptables -A INPUT -p tcp --dport 8069 -j ACCEPT
	ufw allow 8069/tcp
	ufw allow 80/tcp
	ufw allow 443/tcp
}

echo "################################################"
echo "Install OdooScript Development (Experimental)  #"
echo "for Easyway (https://github.com/esfingex)      #"
echo "################################################"
echo ""
echo "Antes que Nada ... Lo escencial *_*"
requirements
echo "Instalando Librería wkhtmltopdf ..."
install_wkhtmltopdf
echo "Instalando PostgreSQL ..."
install_postgres
echo "Instalando pgAdmin4 ..."
install_pgadmin
echo "Instalando Herramientas ..."
easyway_for_ubuntu
echo "Install Librerias Base de Odoo ..."
install_odoo_dev
download_odoo_ver
config_odoo_src
config_odoo_env
echo "Instalando Firewall ..."
gufw_basic
echo "Actualizando SO ..."
update_full > /dev/null
echo "Instalación Finalizada Enjoy 3:)"
