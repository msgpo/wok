#!ipxe

set menu-timeout 3000
dhcp && isset ${filename} && autoboot ||
console --picture http://mirror.slitaz.org/pxe/ipxe/slitaz.png ||

:menu
menu SliTaz net boot menu
item --key b boot	Local boot
item --gap
item --gap Configuration
item --key e exit	iPXE command line
item --key c config	iPXE configuration
isset ${ip} || goto noip
item --gap
item --gap Network boot
isset ${filename} && item --key l lan	Your PXE boot ${filename} ||
item --key w web	SliTaz WEB boot
goto endip
:noip
item --key i ipset	IP settings
:endip
choose --timeout ${menu-timeout} --default web target || goto exit
set menu-timeout 0
isset ${dns} || set dns 8.8.8.8
goto ${target}

:boot
exit

:exit
help
echo Type 'exit' to get the back to the menu
shell
goto menu

:ipset
echo -n IP address: && read net0/ip
set net0/netmask 255.255.255.0
echo -n Subnet mask: ${} && read net0/netmask
echo -n Default gateway: && read net0/gateway
echo -n DNS server: ${} && read dns
goto menu

:web
imgfree
set weburl http://mirror.slitaz.org/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://download.tuxfamily.org/slitaz/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://mirror1.slitaz.org/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://mirror2.slitaz.org/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://mirror3.slitaz.org/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
goto menu

:lan
autoboot ||
goto menu

:config
config
goto menu
