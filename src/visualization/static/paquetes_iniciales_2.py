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

fichero_datos_1      = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/in-doble_pozo_NH3.dat'
fichero_datos_2      = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/in-potencial.dat'
fichero_potencial    = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-potencial_cm-1.dat'
fichero_energias     = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-conver_energias_cm-1.dat'
fichero_paquete_1    = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi1_A.dat'
fichero_paquete_2    = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi2_A.dat'
fichero_paquete_3    = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi3_A.dat'
fichero_paquete_4    = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi4_A.dat'
fichero_puntos_corte = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-puntos_corte.dat'

N, xe, Vb                            = np.loadtxt(fichero_datos_1,   unpack=True, skiprows=1)
xmin, xmax, dx                       = np.loadtxt(fichero_datos_2,   unpack=True, skiprows=1)
x, V                                 = np.loadtxt(fichero_potencial, unpack=True, skiprows=2)
n, Nconver, Econ, E                  = np.loadtxt(fichero_energias,  unpack=True, skiprows=1)
E_Psi0, x, Psi0, dPsi0               = np.loadtxt(fichero_paquete_1, unpack=True, skiprows=3)
E_Psi1, x, Psi1, dPsi1               = np.loadtxt(fichero_paquete_2, unpack=True, skiprows=3)
E_Psi2, x, Psi2, dPsi2               = np.loadtxt(fichero_paquete_3, unpack=True, skiprows=3)
E_Psi3, x, Psi3, dPsi3               = np.loadtxt(fichero_paquete_4, unpack=True, skiprows=3)
alfa, E_alfa, pcx1, pcx2, pcx3, pcx4 = np.loadtxt(fichero_puntos_corte, unpack=True, skiprows=3)

E0 = E_Psi0[0]
E1 = E_Psi1[0]
E2 = E_Psi2[0]
E3 = E_Psi3[0]

RBOHR=0.529177210903      # angstrom
EUACM=2.1947463136320E+05 # hartrees -> cm-1

# xe = xe/RBOHR
# Vb = Vb/EUACM

def x1ee(n):
    res = np.sqrt(np.sqrt(E[n]*Vb)/Vb+1)*xe
    return res
def x2ee(n):
    res = np.sqrt(1-np.sqrt(E[n]*Vb)/Vb)*xe
    return res

# GRAFICA
nombre_grafica = 'paquetes_iniciales_2.pdf'

ymax = 5.5
ymin = -ymax

# width as measured in inkscape
width = 15.922
width = 7.2 * 1.5
# height = width / 1.618
height = 4.45 * 2

width = 7.2/1.5
height = 4.45*2/1.1

fig, axs = plt.subplots(2, figsize=(width, height), sharex=True, sharey='row')

# _________________
# -----------------
xmax = 0.75
xmin = -xmax
ymax = 2500
ymin = 0
multiplicador=150
transparencia=0.5
# _________________
# -----------------
# Lineas horizontales de energia
for j in range(2):
    ax = axs[j]
    for i in range(4):
        ax.hlines(y=E[i], xmin=-x1ee(i), xmax=-x2ee(i), lw=1.0, ls='-', color='gray')
        ax.hlines(y=E[i], xmin= x1ee(i), xmax= x2ee(i), lw=1.0, ls='-', color='gray')
# ==========================================
ax = axs[0]
# ==========================================
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (Psi0*multiplicador) + E0, label=r'$\left| \psi_1 \right>$')
ax.plot(x, (Psi2*multiplicador) + E2, label=r'$\left| \psi_2 \right>$')
ax.set(ylabel=r'$E\ (\mathrm{cm^{-1}})$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')
# ==========================================
ax = axs[1]
# ==========================================
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (dPsi0*multiplicador) + E0, label=r'$\left| \psi_1 \right|^2$')
ax.fill_between(x, (dPsi0*multiplicador) + E0, E0, alpha=transparencia)
ax.plot(x, (dPsi2*multiplicador) + E2, label=r'$\left| \psi_2 \right|^2$')
ax.fill_between(x, (dPsi2*multiplicador) + E2, E2, alpha=transparencia)
ax.set(xlabel=r'$x\ (\AA)$', ylabel=r'$E\ (\mathrm{cm^{-1}})$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
# plt.show()
