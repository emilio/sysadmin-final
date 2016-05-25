---
title: Localhost S.L.
subtitle: Práctica final -- Administración de Sistemas
lang: es-ES
babel-lang: spanish
numbersections: true
toc: true
polyglossia-lang:
  options: []
  name: spanish
author:
  - Emilio Cobos Álvarez (70912324N)
---

# Introducción

## La empresa

La empresa se llama *Localhost SL*[^joke]. Es una empresa especializada en seguridad
y administración de sistemas desde este semestre.

[^joke]: Sí, es un chiste muy malo, aunque me evita tener que cambiar la
configuración del hostname en un par de sitios.

## Prioridades a la hora de la realización de la práctica

Esta práctica es lo suficientemente larga para que a una sola persona le lleve
bastante tiempo.

Por eso, no se ha puesto el mismo empeño en todas las partes de la misma.

Las partes con más empeño han sido las siguientes:

Estabilidad:

  ~ Se ha tratado de construir una infraestructura lo más estable posible. Para
    ello, las tareas de administración más importantes se delegan a un daemon
    (`sysadmin-appd`), que será el encargado de realizarlas, y asegurar que las
    invariantes principales del sistema sean estables.

    Este daemon tiene una serie de tests unitarios extensiva, que aseguran que
    muchos posibles casos sean manejados correctamente.

Seguridad:

  ~ Se ha puesto también un foco importante en la seguridad, especialmente de
    cara a la interfaz web, y a los privilegios de los usuarios.

    Dentro de este aspecto, lo más destacable es:

      * Nivel paranoico de validación de parámetros en la web, prevención de
        inyecciones SQL mediante el uso de `DBI`.

      * Encarcelación de los usuarios en chroot para todos los accesos FTP. Esto
        en particular conlleva una tarea de mantenimiento para las carpetas
        compartidas de la que no estoy orgulloso (se encarga de mantener un
        `mount --bind` dentro de la jaula), pero no estoy seguro de que haya una
        solución mejor.

      * Prevención de la ejecución de código aleatorio en las páginas web de los
        usuarios (mediante el uso de herramientas de blogging estáticas, en este
        caso *Jekyll*).

      * Uso de SSL y FTPS.

Extensibilidad:

  ~ A pesar del tiempo limitado, se ha hecho un esfuerzo en mantener el sistema
    de instalación extensible, para garantizar que más módulos pueden ser
    añadidos sin problemas.

    He de decir que el sistema de instalación necesita algo más de amor, en el
    sentido de que tiene fallos y pequeños fragmentos de configuración que no se
    pueden modificar automáticamente, pero sigue siendo infinitamente mejor que
    una instalación manual.

# Organización del código

El código se ha organizado en módulos parcialmente independientes, de tal manera
que la instalación sea lo más automática posible.

Aún así, es posible que dependiendo de las versiones de los paquetes que se
usen, especialmente *PostgreSQL*, haya que realizar alguna acción manual.

La estructura de directorios es la siguiente:

```
.
├── app
│   ├── dev
│   └── modules
│       ├── apache2
│       │   ├── config
│       │   └── sites
│       ├── backups
│       ├── cgi
│       │   └── cgi
│       │       ├── css
│       │       └── templates
│       ├── daemon
│       │   ├── backups
│       │   ├── init.d
│       │   ├── lib
│       │   │   └── Api
│       │   ├── reporting
│       │   ├── shared-folder
│       │   ├── systemd
│       │   └── tests
│       ├── mail
│       │   └── config
│       ├── moodle
│       ├── postgresql
│       ├── reporting
│       │   ├── sysstat
│       │   └── sysstat-default
│       ├── skel
│       │   └── files
│       │       └── public_html
│       │           ├── css
│       │           ├── _includes
│       │           ├── _layouts
│       │           ├── _posts
│       │           └── _sass
│       ├── webftp
│       └── webmail
│           └── config
│               ├── apache
│               └── roundcube
└── docs
```

La carpeta principal, llamada `app/` es donde están contenidos los módulos,
y las utilidades para el desarrollo (carpeta `dev/`), que consiste básicamente,
en un script para exportar una lista de módulos de perl utilizados gracias
a `Devel::Modlist`.

La carpeta `docs/` contiene la memoria.

## Módulos

### Apache2

Este es el módulo que se encarga de instalar y configurar el servidor web. Se ha
utilizado Apache por simplicidad de configuración (especialmente para *Moodle*),
y por familiaridad.

La instalación de este módulo hace lo siguiente:

#### Instalación paquetes requeridos vía apt y activación de los módulos

Lo primero que hacemos es instalar los paquetes `apache2`, `stow`, `php5`
y `postgresql`, junto con una gran cantidad de módulos de PHP.

Posteriormente activamos los módulos de apache con el comando `a2enmod`,
concretamente los módulos `ssl`, `cgi`, `userdir` y `rewrite`.

#### Activar la sobre-escritura de configuración vía `.htaccess`

Aunque técnicamente es algo más lento, porque los archivos `.htaccess` se
escanean cada solicitud, en la práctica no es perceptible, y permite ser más
flexible con otra gran cantidad de módulos.

El código se encuentra en el archivo `conf/override.conf`.

Nótese que sólo se activa para el directorio `/var/www`, controlado por el
servidor web, y no para los directorios de los usuarios.

#### Configurar `userdir`

Por defecto, `mod_userdir` busca las webs en las carpetas
`/home/xxx/public_html`. Esto no está mal necesariamente, pero por cómo vamos
a montar los blogs de los usuarios, nos interesa buscar antes en
`/home/xxx/public_html/_site`.

#### Configurar el sitio principal

Se reemplaza el sitio por defecto de Apache (`000-default`) por una
configuración personalizada que activa SSL con los certificados por defecto
(`/etc/ssl/certs/ssl-cert-snakeoil.pem`), y redirige a https automáticamente.

### Daemon

Este es el módulo más interesante con mucha diferencia. De este módulo se nutren
tanto el back-end de la web CGI, como otros scripts que necesiten, por ejemplo,
mandar e-mails.

Se crea un alias de este módulo mediante un links simbólico
a `/etc/sysadmin-app`. Esto servirá para tener un path de referencia en todos
los lugares.

A grandes rasgos, el daemon es un servicio que escuchará continuamente en el
host local al puerto 7777 para realizar acciones privilegiadas de una manera
controlada y segura. Esta es una de las razones por las que se desactiva el
acceso vía ssh a los usuarios[^safety-note].

[^safety-note]: No es excesivamente complicado buscar un modelo de seguridad
alternativo, pero eso conllevaría bastante más desarrollo.

#### Creación de la base de datos

La base de datos utilizada es muy sencilla. Para la autenticación se utiliza la
contraseña del sistema, por lo tanto no es necesario almacenar ningún tipo de
contraseña ahí.

La base de datos sirve, principalmente, para guardar los datos extra que Linux
no almacena automáticamente, y que son requeridos por el enunciado de la
práctica, es decir:

  * Una dirección de correo electrónico (para recuperar la contraseña).
  * Una dirección postal (requerido por el enunciado).
  * Un token opcional (usado durante el proceso de recuperación de la
    contraseña).

Los datos de acceso a la base de datos y del mailer se especifican durante la
instalación, y deben de ser configurados mediante un archivo
(`/etc/sysadmin-app/sysadminapprc`).

#### Implementación del daemon y del cliente

El código está dividido en dos partes:

  * Un servidor, que está diseñado para correr como `root` y ser el encargado de
    leer comandos y realizar acciones privilegiadas del sistema
    (`lib/Api/Server.pm`).

  * Un cliente, que se encarga de las acciones no privilegiadas (como tocar la
    base de datos con los datos y mandar e-mails), y de llamar al servidor para
    las acciones privilegiadas.

Todo esto se instala como servicio (ver los archivos `init.d/` y `systemd/` para
las respectivas versiones), usando el módulo `Proc::Daemon` en el programa
`sysadmin-app.pl`.

#### Back-ups

En esta carpeta, al ser la carpeta de referencia, están los scripts que se
ejecutan regularmente, como el de backup, que es un back-up incremental del
directorio `/home/` (script `backups/do-backup`).

#### Mantenimiento de sitios personales y carpeta compartida

La carpeta compartida (`/etc/sysadmin-app/apuntes`) se mantiene en los
directorios de los usuarios teniéndola montada en el directorio home, con un
`mount --bind`.

Esto permite que se pueda mantener la jaula de `chroot` en ftp, pero tiene un
coste: Tenemos que mantener los links actualizados, y hacer limpieza de
usuarios.

Ese es el objetivo del script `shared-folder/ensure-shared-folder-accessible`,
que monta la carpeta periódicamente.

Aprovechando esta iteración, también reconstruímos los sitios personales de los
usuarios con `jekyll`, y limpiamos todo lo que pertenezca a un usuario ya
borrado.

#### Reporting

% TODO

#### Tests unitarios del daemon

% TODO

### Backups

El módulo de backups sólo se encarga de configurar un crontab convenientemente
para que ejecute un script en la carpeta `/etc/sysadmin-app/backups`, que hemos
comentado antes.
