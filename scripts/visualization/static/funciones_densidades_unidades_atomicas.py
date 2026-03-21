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

fichero_datos_1                = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/in-doble_pozo_NH3.dat'
fichero_datos_2                = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/in-potencial.dat'
fichero_potencial              = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-potencial_hartrees.dat'
fichero_energias               = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-conver_energias_hartrees.dat'
fichero_funciones_pares        = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-funciones_pares_hartrees.dat'
fichero_funciones_impares      = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-funciones_impares_hartrees.dat'
fichero_densidad_prob_pares    = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-densidad_prob_pares_hartrees.dat'
fichero_densidad_prob_impares  = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-densidad_prob_impares_hartrees.dat'

N, xe, Vb = np.loadtxt(fichero_datos_1, unpack=True, skiprows=1)
xmin, xmax, dx = np.loadtxt(fichero_datos_2, unpack=True, skiprows=1)
x, V = np.loadtxt(fichero_potencial, unpack=True, skiprows=2)
n, E, Nconver = np.loadtxt(fichero_energias, unpack=True, skiprows=1)
x, Phi0, Phi2, Phi4 = np.loadtxt(fichero_funciones_pares, unpack=True, skiprows=2)
x, Phi1, Phi3, Phi5 = np.loadtxt(fichero_funciones_impares, unpack=True, skiprows=2)
x, dPhi0, dPhi2, dPhi4 = np.loadtxt(fichero_densidad_prob_pares, unpack=True, skiprows=2)
x, dPhi1, dPhi3, dPhi5 = np.loadtxt(fichero_densidad_prob_impares, unpack=True, skiprows=2)

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
nombre_grafica = 'funciones_densidades_unidades_atomicas.pdf'

xmax = 1.5
xmin = -xmax
ymax = 1.5
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
ax.plot(x, dPhi0, label=r'$\left| \Phi_0 \right|^2$')
ax.plot(x, Phi0, label=r'$\left| \Phi_0 \right>$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

# ==========================================
ax = axs[0][1]
# ==========================================
ax.axvline(x=-xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.plot(x, dPhi1, label=r'$\left| \Phi_1 \right|^2$')
ax.plot(x, Phi1, label=r'$\left| \Phi_1 \right>$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

# ==========================================
ax = axs[1][0]
# ==========================================
ax.axvline(x=-xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.plot(x, dPhi2, label=r'$\left| \Phi_2 \right|^2$')
ax.plot(x, Phi2, label=r'$\left| \Phi_2 \right>$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.set(xlabel=r'$x\ (a_0)$')
ax.legend(loc='upper right')

# ==========================================
ax = axs[1][1]
# ==========================================
ax.axvline(x=-xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.axvline(x=xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
ax.plot(x, dPhi3, label=r'$\left| \Phi_3 \right|^2$')
ax.plot(x, Phi3, label=r'$\left| \Phi_3 \right>$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.set(xlabel=r'$x\ (a_0)$')
ax.legend(loc='upper right')

plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
# plt.show()
