#!/bin/bash
######################################
#                                    #
# Este script solo soporta versiones #
# de ubuntu 18.04, 20.04 (LTS)       #
# Iván Masías                        # 
# https://github.com/esfingex        #
######################################

#DEFINE
odoov=14			#Versión odoo a instalar
release=$(lsb_release -cs)	#Versión de SO (solo ubuntu)

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

	#Agrega librería repositorios de Python con versiones anteriores (ubuntu 20.04)
	if [ $release == 'focal' ];
	then add-apt-repository ppa:deadsnakes/ppa -y > /dev/null
	fi

	apt-get install gpg lsb-release -y > /dev/null
	echo ""

}

#Consulta arquitectura
if [ $(arch) == 'x86_64' ]; then archtype=[arch=amd64]; fi

function install_postgres(){
	text="deb ${archtype} http://apt.postgresql.org/pub/repos/apt $release-pgdg main"
	echo $text >> /etc/apt/sources.list.d/pgdg.list
	echo "---> PostgreSQL Key ... "
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
	echo "---> Actualizando ... "
	update > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-get install libpq-dev postgresql -y > /dev/null
	echo ""
}

function install_pgadmin(){
	text="deb ${archtype} https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$release pgadmin4 main"
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
	esac

	#Configuración
	mkdir download
	chmod 777 -R download
	wget -q -P download $url_get$wkhtmltox
	echo "---> Instalando Paquetes ... "
	dpkg -i download/$wkhtmltox > /dev/null
	rm -R download/
	update > /dev/null
	echo ""
}

function install_gith_desk(){
	text="deb ${archtype} https://packagecloud.io/shiftkey/desktop/any/ any main"
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
	text="deb ${archtype} https://packages.microsoft.com/repos/code stable main"
	echo $text >> /etc/apt/sources.list.d/vscode.list
	echo "---> VScode Key ... "
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
	echo "---> Actualizando ... "
	update > /dev/null
	echo "---> Instalando Paquetes ... "
	apt-get install apt-transport-https code -y > /dev/null
	echo ""
}

function install_odoo(){
	echo "Instalando Dependencias de Odoo ..."
	apt-get install  git libxml2-dev libjpeg-dev libsasl2-dev libldap2-dev libssl-dev zlib1g-dev libxslt1-dev libldap2-dev python3.7 python3.7-dev python3-pip python3-virtualenv -y > /dev/null
	#Repara el error de path que ocurre en Ubuntu
	export PATH=$PATH:/home/$USER/.local/bin	
	pip3 install --upgrade pip > /dev/null

	echo "Configurando Odoo ..."
	#Estructura de Addons
	echo "---> Estructura Directorios ..."
	mkdir /opt/odoo
	mkdir /opt/odoo/odoo${odoov}

	#Descarga odoo
	echo "---> Descarga Odoo SRC ..."
	wget -q https://nightly.odoo.com/${odoov}.0/nightly/src/odoo_${odoov}.0.latest.tar.gz		#Descarga
	echo "---> Descomprimiendo ..."
	tar -xf odoo_${odoov}.0.latest.tar.gz > /dev/null						#Descomprime
	mv odoo-${odoov}.* odoo${odoov}									#Cambia el nombre
	cp -R odoo${odoov}/ /opt/odoo/odoo${odoov}							#Copia a directorio
	chmod 777 -R /opt/odoo/odoo${odoov}								#Asignación de permisos
	rm odoo_${odoov}.0.latest.tar.gz								#Borra el temp
	rm -R odoo${odoov}
}

function config_odoo(){
	#Instalacion Enviroments
	echo "---> Creando Enviroments ..."
	mkdir /opt/odoo/venv
	chmod 777 -R /opt/odoo/venv
	virtualenv -p /usr/bin/python3.7 /opt/odoo/venv/odoo${odoov} > /dev/null
	source /opt/odoo/venv/odoo${odoov}/bin/activate
	pip install pip --upgrade > /dev/null
	echo "---> Instalando Dependencias Python ..."
	pip install -r /opt/odoo/odoo${odoov}/odoo/requirements.txt > /dev/null
	echo "---> Creando Workspace para VScode ..."
	mkdir /home/$USER/workspace/odoovs
	#echo ""
}


echo "############################################"
echo "Install OdooScript Development             #"
echo "for Easyway (https://github.com/esfingex)  #"
echo "############################################"
echo ""
echo "Antes que Nada ... Lo escencial *_*"
requirements
echo "Instalando Librería wkhtmltopdf ..."
install_wkhtmltopdf
echo "Instalando PostgreSQL ..."
install_postgres
echo "Instalando pgAdmin4 ..."
install_pgadmin
echo "Instalando VScode ..."
install_vscode
echo "Instalando Github Desktop ..."
install_gith_desk
echo "Install Odoo ..."
install_odoo
config_odoo
echo "Actualizando SO ..."
update > /dev/null

echo "Instalación Finalizada Enjoy 3:)"



