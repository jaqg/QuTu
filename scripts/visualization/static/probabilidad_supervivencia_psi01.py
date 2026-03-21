# _____________________________________________________________________________
# *****************************************************************************
# Autor: José Antonio Quiñonero gris
# Fecha de creación: 1 de junio de 2022
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

nombre_grafica = 'probabilidad_supervivencia_psi01.pdf'


fichero_datos_1 = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-probabilidad_supervivencia_Psi0.dat'
fichero_datos_2 = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-probabilidad_supervivencia_Psi1.dat'
t_Psi0, Ps_Psi0 = np.loadtxt(fichero_datos_1, unpack=True, skiprows=1)
t_Psi1, Ps_Psi1 = np.loadtxt(fichero_datos_2, unpack=True, skiprows=1)

# GRAFICA
# width as measured in inkscape
# width = 15.922
# height = width / 1.618

numero_subplots = 2
# width = 5 #Default 7.2x4.45
# height = width*(4.45/7.2)

width = 7.2*1.5
height = 4.45

fig, axs = plt.subplots(1,2,figsize=(width, height), sharey=True)
fig.subplots_adjust(left=.15, bottom=.16, right=.99, top=.97)

# =========
ax = axs[0]
xmin = 0
xmax = 50
ymin = 0
ymax = 1
ax.plot(t_Psi0, Ps_Psi0, label=r'$P_s^{(0)}(t)$')
ax.set(title=r'$P_s(t)$ de $\Psi = \left( \Phi_0 \pm \Phi_1 \right)/\sqrt{2}$', xlabel=r'$t\ (\mathrm{ps})$ ', ylabel=r'$P_s(t)$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

# =========
ax = axs[1]
xmin = 0
xmax = 1
ymin = 0
ymax = 1
ax.plot(t_Psi1, Ps_Psi1, label=r'$P_s^{(1)}(t)$')
ax.set(title=r'$P_s(t)$ de $\Psi = \left( \Phi_2 \pm \Phi_3 \right)/\sqrt{2}$', xlabel=r'$t\ (\mathrm{ps})$ ')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')

plt.savefig(nombre_grafica)
