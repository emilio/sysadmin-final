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

[^joke]: Sí, es un chiste muy malo, aunque la idea era que me evitara tener que
cambiar la configuración del hostname en un par de sitios, se acabó usando el
hostname `localhost.sl`.

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

La base de datos utilizada es muy sencilla. Para la autenticación de usuarios se
utiliza la contraseña del sistema, por lo tanto no es necesario almacenar ningún
tipo de contraseña ahí.

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
    las acciones privilegiadas (`lib/api/Client.pm`).

Todo esto se instala como servicio (ver los archivos `init.d/` y `systemd/` para
las respectivas versiones), usando el módulo `Proc::Daemon` en el programa
`sysadmin-app.pl`.

#### Back-ups

En esta carpeta, al ser la carpeta de referencia, están los scripts que se
ejecutan regularmente, como el de backup, que es un back-up incremental del
directorio `/home/` (script `backups/do-backup`).

El backup se sube remotamente vía `scp` a un servidor externo una vez a la
semana.

#### Mantenimiento de sitios personales y carpeta compartida

La carpeta compartida (`/etc/sysadmin-app/apuntes`) se mantiene en los
directorios de los usuarios teniéndola montada en el directorio home, con un
`mount --bind`.

Esto permite que se pueda mantener la jaula de `chroot` en ftp, pero tiene un
coste: Tenemos que mantener los links actualizados, y hacer limpieza de
usuarios.

Ese es el objetivo del script `shared-folder/ensure-shared-folder-accessible`,
que monta la carpeta periódicamente.

Aprovechando esta iteración, también reconstruimos los sitios personales de los
usuarios con `jekyll`, y limpiamos todo lo que pertenezca a un usuario ya
borrado.

#### Reporting

El reporte de estadísticas es un programa Perl que devuelve las estadísticas de
determinados comandos.

Se hace una excepción acerca de llamar a comandos directamente desde perl, dado
que:

  a) No se encontraron módulos de CPAN que reportaran estos datos de forma
     simple.
  b) Era más simple, pudiendo reutilizar la configuración SMTP de la aplicación
     en vez de ponerla a mano en un script `sh`.

#### Tests unitarios del daemon

El daemon tiene una suite extensiva de tests unitarios en el archivo
`tests/create_delete_user.pl`. Son un total de 32 tests que comprueban el
funcionamiento correcto del programa.

### Backups

El módulo de backups sólo se encarga de configurar un crontab convenientemente
para que ejecute un script en la carpeta `/etc/sysadmin-app/backups`, que hemos
comentado antes.

### CGI

El módulo CGI es el que contiene la mayoría de la interfaz web, salvo la página
principal.

La funcionalidad es bastante directa, utiliza el módulo `CGI::Simple`, junto con
el módulo `CGI::Session` para mantener la sesión, y el módulo `CGI::Template`
para la apariencia de la web.

Toda la funcionalidad relacionada con los usuarios se realiza a través del
daemon, por ejemplo, este es el código (simplificado) para realizar el login:

```perl
my $request = new CGI();
my $template = new CGI::Template();
my $session = new CGI::Session("id:md5", $request, {Directory=>'/tmp'});
my $api_client = new Api::Client();

my $user_name = $request->param("user_name");
my $password = $request->param("password");

if ($request->request_method ne "POST" or !$user_name or !$password) {
  print $request->redirect("login.pl");
  exit 0;
}

my ($correct_login, $token) = $api_client->check_login($user_name, $password);
if (!$correct_login) {
  $template->error("Login error, re-check your credentials");
}

$session->param("user_name", $user_name);
$session->param("login_token", $token);
```

### Mail

El módulo de mail simplemente instala postfix con la configuración adecuada para
permitir mail local y configurar los límites del mailbox.

### Moodle

Este módulo realiza una instalación limpia de moodle en el directorio
`/var/www/html/moodle`.

La instalación de moodle trató de ser configurada con un módulo de autenticación
via `IMAP` (que resultó no funcionar), y también `PAM`, que fue un caos de
configurar, pero que también resultó fallar sin un error claro, por lo que la
parte de que los usuarios de la aplicación se sincronicen con los de moodle no
se consiguió.

### PostgreSQL

Este módulo se encarga de instalar PostgreSQL, no tiene más utilidad.

### Skel

Este módulo realiza diversas funciones:

  1. Instala el crontab encargado de mantener los directorios compartidos. Esto
     está ubicado aquí porque el primer diseño tenía el directorio compartido en
     la carpeta `skel/` con un symlink (algo que por razones obvias no funciona
     cuando hay un `chroot` de por medio).
  2. Copia los ficheros en la carpeta `/etc/skel`. Esto incluye un sitio de
     Jekyll por defecto, que será lo utilizado para el blog personal.

### WebFTP

El módulo de WebFTP se encarga de instalar `vsftp`[^recompilation],
y configurarlo adecuadamente para que todos los usuarios usen chroot y queden
enjaulados en su directorio home.

A partir de ahí, instala una copia de `MonstaFTP` en la carpeta
`/var/www/html/mftp`.

[^recompilation]: Como nota curiosa, me tocó recompilar vsftp a mano para
obtener la versión 3.x del mismo, ya que no se encontraba en los paquetes de
Debian y sólo a partir de esa versión se soportaba la opción
`allow_writeable_chroot`.

### WebMail

El módulo WebMail contiene la configuración necesaria para instalar roundcube
y ponerlo a funcionar en apache bajo el directorio `/rc`, usando por defecto el
host IMAP local.

Se eligió roundcube porque la configuración usando el paquete de Debian es
extremadamente sencilla, y provee toda la funcionalidad necesaria.

# Funcionalidades extra propuestas

Se proponían varias funcionalidades extra dentro de la práctica, a continuación
se expone cuáles se implementaron y cuáles no.

## Backups remotas

Este apartado está realizado mediante la subida mediante `scp` del backup
semanal a un servidor remoto.

## Bloqueo de páginas web

Esto no se ha implementado, no obstante es relativamente sencillo si se quiere
hacer, aunque personalmente el autor de esta memoria no le ve demasiado sentido
por varias razones:

  * El ordenador es supuestamente un servidor, es difícil pensar que los alumnos
    se conectarían a internet a través de él.
  * Incluso aunque así fuera, la extensión masiva del uso de datos móviles haría
    que esta medida no fuera sino una medida evitable a un click de distancia.

No obstante, como propuesta de dos líneas para solucionarlo se propone apuntar
las entradas de dominios no deseados en el archivo `/etc/hosts` a direcciones
erróneas.

## Contraseña del administrador

Sobre el robo de la contraseña del administrador, se ha desactivado el acceso
ssh como root a la máquina de prueba. Esta es una solución más que viable si se
tiene acceso físico a la máquina, ya que si el atacante tuviera acceso físico
a la máquina estaría todo perdido de antemano.

Si hiciera falta administrar la máquina remotamente, la forma más viable de
hacerlo es haciendo que las personas con permiso para la administración tuvieran
una clave ssh personal, cada uno con una contraseña adecuada.

Así, es extremadamente fácil auditar si ha habido un acceso no autorizado a la
máquina, y de ser así quién es el responsable (ya sea por filtrar datos de
acceso o por perder tanto la clave ssh como la contraseña).

## Comunicación entre alumnos

Este punto no está hecho, principalmente por falta de tiempo.

## Registro automático en Moodle

Como se comentó arriba, esto se trató de hacer, tanto mediante `IMAP`, como
mediante `PAM`, sin resultados favorables. Todo sea dicho, fue la última cosa en
ser intentada, y por lo tanto el tiempo gastado en intentar hacerlo funcionar
fue menor que otra funcionalidad.

Idealmente hubiera puesto un servidor `LDAP`, pero eso hubiera conllevado
reescribir una buena parte del código Perl escrito para la práctica.

# Conclusión

El sistema realizado no es ideal, pero cumple los requisitos de manera, cuanto
menos, decente.

Lo cierto es que, tras este intento, la arquitectura que utilizaría si tuviera
que re-hacer la práctica de nuevo con tiempo ilimitado sería un servidor
`LDAP` en una IP designada, donde se crearían las cuentas de los usuarios, y del
que tiraría la autenticación todos los servicios que se usaran (incluso el
mail, que sería potencialmente mediante cuentas virtuales, incluso en un
servidor remoto).

Así, al menos una cuenta con privilegios sería creada por el administrador
principal, y luego esas cuentas (por ejemplo, pertenecientes a la gente de
secretaría) serían las encargadas de dar de alta al resto de usuarios con
un nivel de permisos adecuados (potencialmente desde una aplicación como la
creada, pero que requiriese estar logueado con una cuenta con ese tipo de
privilegios).

Esto permitiría una descentralización prácticamente absoluta de casi cualquier
servicio, y con una integración mínima (tal vez habría que hacer algo para
integrar los permisos de las cuentas de LDAP con otros servicios, como Moodle,
pero toda esa lógica residiría en el servicio externo en cualquier caso).

Por lo tanto, aunque esté bastante contento con la estrategia adecuada para
realizar acciones privilegiadas que se ha tomado, soy consciente de que no es la
mejor estrategia posible[^ssh-hell], aunque el tiempo disponible para la
realización de la práctica ha de ser tenido en cuenta también.


[^ssh-hell]: Nótese que el daemon actual estaría roto si los usuarios locales
tuvieran acceso vía ssh, ya que podrían conectarse al puerto 7777. Si se
quisiera proporcionar acceso ssh a los usuarios, un sistema de autenticación
tendría que ser desarrollado para el daemon, desde algo sencillo como tener una
clave generada sólo accesible para determinados usuarios, hasta algo más
complejo con algún tipo de *hand-shake*.
