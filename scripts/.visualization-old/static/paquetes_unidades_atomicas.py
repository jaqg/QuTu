# _____________________________________________________________________________
# *****************************************************************************
# Autor: José Antonio Quiñonero gris
# Fecha de creación: 12 de abril de 2022
# *****************************************************************************
# -----------------------------------------------------------------------------

# descripcion del programa

# Librerias
import numpy as np
import matplotlib.pyplot as plt

plt.style.use('mine')

# *****************************************************************************
# INICIO
# *****************************************************************************

fichero_datos_1   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/in-doble_pozo_NH3.dat'
fichero_datos_2   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/in-potencial.dat'
fichero_potencial = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-potencial_hartrees.dat'
fichero_energias  = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-conver_energias_hartrees.dat'
fichero_paquete_1 = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi1.dat'
fichero_paquete_2 = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi2.dat'
fichero_paquete_3 = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi3.dat'
fichero_paquete_4 = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi4.dat'

N, xe, Vb      = np.loadtxt(fichero_datos_1,   unpack=True, skiprows=1)
xmin, xmax, dx = np.loadtxt(fichero_datos_2,   unpack=True, skiprows=1)
x, V           = np.loadtxt(fichero_potencial, unpack=True, skiprows=2)
n, E, Nconver  = np.loadtxt(fichero_energias,  unpack=True, skiprows=1)
E_Psi0, x, Psi0, dPsi0 = np.loadtxt(fichero_paquete_1, unpack=True, skiprows=4)
E_Psi0, x, Psi1, dPsi1 = np.loadtxt(fichero_paquete_2, unpack=True, skiprows=4)
E_Psi0, x, Psi2, dPsi2 = np.loadtxt(fichero_paquete_3, unpack=True, skiprows=4)
E_Psi0, x, Psi3, dPsi3 = np.loadtxt(fichero_paquete_4, unpack=True, skiprows=4)

RBOHR=0.529177210903      # angstrom
EUACM=2.1947463136320E+05 # hartrees -> cm-1

xe = xe/RBOHR
Vb = Vb/EUACM

def x1(n):
    res = np.sqrt(np.sqrt(E[n]*Vb)/Vb+1)*xe
    return res
def x2(n):
    res = np.sqrt(1-np.sqrt(E[n]*Vb)/Vb)*xe
    return res

# GRAFICA
nombre_grafica = 'paquetes_unidades_atomicas.pdf'

xmax = 1.5
xmin = -xmax
ymax = 3
ymin = -ymax

# width as measured in inkscape
width = 15.922
width = 7.2 * 1.5
# height = width / 1.618
height = 4.45 * 2

fig, axs = plt.subplots(2,2, figsize=(width, height), sharey=True, sharex=True)

# ==========================================
ax = axs[0][0]
# ==========================================
ax.axvline(x=-xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=0, ymin=ymin, ymax=ymax, lw=1.0, ls='-', color='k')
ax.axhline(y=0, xmin=xmin, xmax=xmax, lw=1.0, ls='-', color='k')
ax.plot(x, dPsi0, label=r'$\left| \Psi \right|^2$')
ax.plot(x, Psi0, label=r'$\left| \Psi \right>$')
ax.set(title=r'$\Psi = \left( \Phi_0 + \Phi_1 \right)/\sqrt{2}$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

# ==========================================
ax = axs[0][1]
# ==========================================
ax.axvline(x=-xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=0, ymin=ymin, ymax=ymax, lw=1.0, ls='-', color='k')
ax.axhline(y=0, xmin=xmin, xmax=xmax, lw=1.0, ls='-', color='k')
ax.plot(x, dPsi1, label=r'$\left| \Psi \right|^2$')
ax.plot(x, Psi1, label=r'$\left| \Psi \right>$')
ax.set(title=r'$\Psi = \left( \Phi_0 - \Phi_1 \right)/\sqrt{2}$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

# ==========================================
ax = axs[1][0]
# ==========================================
ax.axvline(x=-xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=0, ymin=ymin, ymax=ymax, lw=1.0, ls='-', color='k')
ax.axhline(y=0, xmin=xmin, xmax=xmax, lw=1.0, ls='-', color='k')
ax.plot(x, dPsi2, label=r'$\left| \Psi \right|^2$')
ax.plot(x, Psi2, label=r'$\left| \Psi \right>$')
ax.set(title=r'$\Psi = \left( \Phi_2 + \Phi_3 \right)/\sqrt{2}$', xlabel=r'$x\ (a_0)$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

# ==========================================
ax = axs[1][1]
# ==========================================
ax.axvline(x=-xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=0, ymin=ymin, ymax=ymax, lw=1.0, ls='-', color='k')
ax.axhline(y=0, xmin=xmin, xmax=xmax, lw=1.0, ls='-', color='k')
ax.plot(x, dPsi3, label=r'$\left| \Psi \right|^2$')
ax.plot(x, Psi3, label=r'$\left| \Psi \right>$')
ax.set(title=r'$\Psi = \left( \Phi_2 - \Phi_2 \right)/\sqrt{2}$', xlabel=r'$x\ (a_0)$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
# plt.show()
