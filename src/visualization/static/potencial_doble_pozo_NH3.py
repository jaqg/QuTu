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
fichero_potencial = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-potencial_cm-1.dat'
fichero_energias  = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-conver_energias_cm-1.dat'

N, xe, Vb = np.loadtxt(fichero_datos_1, unpack=True, skiprows=1)
xmin, xmax, dx = np.loadtxt(fichero_datos_2, unpack=True, skiprows=1)
x, V = np.loadtxt(fichero_potencial, unpack=True, skiprows=2)
n, E, Nconver = np.loadtxt(fichero_energias, unpack=True, skiprows=1)

# print(V)
print(E)

RBOHR=0.529177210903      # angstrom
EUACM=2.1947463136320E+05 # hartrees -> cm-1

# xe = xe/RBOHR
# Vb = Vb/EUACM

def Vcalc(x):
    res = (Vb/xe**4)*x**4 - (2*Vb/xe**2)*x**2 + Vb
    return res

def x1(n):
    res = np.sqrt(np.sqrt(E[n]*Vb)/Vb+1)*xe
    return res
def x2(n):
    res = np.sqrt(1-np.sqrt(E[n]*Vb)/Vb)*xe
    return res

# GRAFICA
nombre_grafica = 'potencial_doble_pozo_NH3.pdf'

xmax = 1
xmin = -xmax
ymin = 0
ymax = 3000

width  = 6.3
height = width/1.6

fig, ax = plt.subplots(figsize=(width, height))

# Niveles de energia
for i in np.arange(0,len(E)):
    if E[i]<=Vb:
        ax.hlines(y = E[i], xmin=-x1(i), xmax=-x2(i), color='black', lw=1.0)
        ax.hlines(y = E[i], xmin=x2(i), xmax=x1(i), color='black', lw=1.0)
    else:
        ax.hlines(y = E[i], xmin=-x1(i), xmax=x1(i), color='black', lw=1.0)

ax.plot(x, V, label=r'$V\,(x)$', color='grey')
# ax.plot(x, Vcalc(x), label=r'$V\,(x)$', color='k')

ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)

ax.set(xlabel=r'$x\ (\AA)$', ylabel=r'$E\ (\mathrm{cm^{-1}})$')

# handles, labels = ax.get_legend_handles_labels()
# axs[1].legend(handles[::-1], labels[::-1], loc=(1.01,0.4))
ax.legend(loc='upper right')

plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
# plt.show()
