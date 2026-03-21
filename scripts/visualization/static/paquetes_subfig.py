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
fichero_puntos_corte = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-puntos_corte.dat'

N, xe, Vb                            = np.loadtxt(fichero_datos_1,   unpack=True, skiprows=1)
xmin, xmax, dx                       = np.loadtxt(fichero_datos_2,   unpack=True, skiprows=1)
x, V                                 = np.loadtxt(fichero_potencial, unpack=True, skiprows=2)
n, Nconver, Econ, E                  = np.loadtxt(fichero_energias,  unpack=True, skiprows=1)
alfa, E_alfa, pcx1, pcx2, pcx3, pcx4 = np.loadtxt(fichero_puntos_corte, unpack=True, skiprows=3)

RBOHR=0.529177210903      # angstrom
EUACM=2.1947463136320E+05 # hartrees -> cm-1
#
# xe = xe/RBOHR
# Vb = Vb/EUACM
#
def x1ee(n):
    res = np.sqrt(np.sqrt(E[n]*Vb)/Vb+1)*xe
    return res
def x2ee(n):
    res = np.sqrt(1-np.sqrt(E[n]*Vb)/Vb)*xe
    return res

def set_share_axes(axs, target=None, sharex=False, sharey=False):
    if target is None:
        target = axs.flat[0]
    # Manage share using grouper objects
    for ax in axs.flat:
        if sharex:
            # target._shared_x_axes.join(target, ax)
            target._shared_axes['x'].join(target, ax)
        if sharey:
            # target._shared_y_axes.join(target, ax)
            target._shared_axes['y'].join(target, ax)
    # Turn off x tick labels and offset text for all but the bottom row
    if sharex and axs.ndim > 1:
        for ax in axs[:-1,:].flat:
            ax.xaxis.set_tick_params(which='both', labelbottom=False, labeltop=False)
            ax.xaxis.offsetText.set_visible(False)
    # Turn off y tick labels and offset text for all but the left most column
    if sharey and axs.ndim > 1:
        for ax in axs[:,1:].flat:
            ax.yaxis.set_tick_params(which='both', labelleft=False, labelright=False)
            ax.yaxis.offsetText.set_visible(False)

#
# width as measured in inkscape
width = 15.922
width = 7.2 * 1.5
width = 5.4
# height = width / 1.618
height = 4.45
#
width = 8.268
height = 11.693
fig, axs = plt.subplots(4,2,figsize=(width, height))
# gridspec_kw={'height_ratios': [1, 1, 3]}
# wspace=0.1, hspace=0.1, left=0.1, right=0.4, bottom=0.1, top=0.9
set_share_axes(axs[:3,:], sharex=True, sharey=True)
set_share_axes(axs[:4,:1], sharex=True, sharey=True)

lista_alfa_4EE = [0, 15, 30, 45, 60, 75, 90]

# Lineas horizontales de energia
for i in range(4):
    for j in range(2):
        ax = axs[i][j]
        for l in range(4):
            ax.hlines(y=E[l], xmin=-x1ee(l), xmax=-x2ee(l), lw=1.0, ls='-', color='gray')
            ax.hlines(y=E[l], xmin= x1ee(l), xmax= x2ee(l), lw=1.0, ls='-', color='gray')
# ------------------------------------------------
nombre_grafica = 'paquetes_subfig.pdf'
xmax = 0.75
xmin = -xmax
ymax = 2500
ymin = 0
multiplicador=150
transparencia=0.5
# ------------------------------------------------
# ============
ax = axs[0][0]
# ============
alfa_4EE = 0
x1 = pcx1[0]
x2 = pcx2[0]
x3 = pcx3[0]
x4 = pcx4[0]
fichero_paquete   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi_4EE_alfa={}.dat'.format(alfa_4EE)
alfa_malo, E_Psi, x, Psi, dPsi = np.loadtxt(fichero_paquete, unpack=True, skiprows=4)
ax.hlines(y=E_Psi[0], xmin=x1, xmax=x2, lw=1.0, ls='-', color='k')
ax.hlines(y=E_Psi[0], xmin=x3, xmax=x4, lw=1.0, ls='-', color='k')
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (dPsi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right|^2$')
# ax.fill_between(x, (dPsi*multiplicador) + E_Psi[0], E_Psi[0], alpha=transparencia)
ax.plot(x, (Psi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right>$')
ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE), ylabel=r'$E\ (\mathrm{cm^{-1}})$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')
# ============
ax = axs[1][0]
# ============
alfa_4EE = 15
x1 = pcx1[2]
x2 = pcx2[2]
x3 = pcx3[2]
x4 = pcx4[2]
fichero_paquete   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi_4EE_alfa={}.dat'.format(alfa_4EE)
alfa_malo, E_Psi, x, Psi, dPsi = np.loadtxt(fichero_paquete, unpack=True, skiprows=4)
ax.hlines(y=E_Psi[0], xmin=x1, xmax=x2, lw=1.0, ls='-', color='k')
ax.hlines(y=E_Psi[0], xmin=x3, xmax=x4, lw=1.0, ls='-', color='k')
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (dPsi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right|^2$')
ax.plot(x, (Psi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right>$')
ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE), ylabel=r'$E\ (\mathrm{cm^{-1}})$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')
# ============
ax = axs[2][0]
# ============
alfa_4EE = 30
x1 = pcx1[4]
x2 = pcx2[4]
x3 = pcx3[4]
x4 = pcx4[4]
fichero_paquete   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi_4EE_alfa={}.dat'.format(alfa_4EE)
alfa_malo, E_Psi, x, Psi, dPsi = np.loadtxt(fichero_paquete, unpack=True, skiprows=4)
ax.hlines(y=E_Psi[0], xmin=x1, xmax=x2, lw=1.0, ls='-', color='k')
ax.hlines(y=E_Psi[0], xmin=x3, xmax=x4, lw=1.0, ls='-', color='k')
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (dPsi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right|^2$')
ax.plot(x, (Psi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right>$')
ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE), ylabel=r'$E\ (\mathrm{cm^{-1}})$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')
# ============
ax = axs[3][0]
# ============
alfa_4EE = 45
x1 = pcx1[6]
x2 = pcx2[6]
x3 = pcx3[6]
x4 = pcx4[6]
fichero_paquete   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi_4EE_alfa={}.dat'.format(alfa_4EE)
alfa_malo, E_Psi, x, Psi, dPsi = np.loadtxt(fichero_paquete, unpack=True, skiprows=4)
ax.hlines(y=E_Psi[0], xmin=x1, xmax=x2, lw=1.0, ls='-', color='k')
ax.hlines(y=E_Psi[0], xmin=x3, xmax=x4, lw=1.0, ls='-', color='k')
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (dPsi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right|^2$')
ax.plot(x, (Psi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right>$')
ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE), xlabel=r'$x\ (\AA)$', ylabel=r'$E\ (\mathrm{cm^{-1}})$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')
# ============
ax = axs[0][1]
# ============
alfa_4EE = 60
x1 = pcx1[8]
x2 = pcx2[8]
x3 = pcx3[8]
x4 = pcx4[8]
fichero_paquete   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi_4EE_alfa={}.dat'.format(alfa_4EE)
alfa_malo, E_Psi, x, Psi, dPsi = np.loadtxt(fichero_paquete, unpack=True, skiprows=4)
ax.hlines(y=E_Psi[0], xmin=x1, xmax=x2, lw=1.0, ls='-', color='k')
ax.hlines(y=E_Psi[0], xmin=x3, xmax=x4, lw=1.0, ls='-', color='k')
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (dPsi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right|^2$')
ax.plot(x, (Psi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right>$')
ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE))
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')
# ============
ax = axs[1][1]
# ============
alfa_4EE = 75
x1 = pcx1[10]
x2 = pcx2[10]
x3 = pcx3[10]
x4 = pcx4[10]
fichero_paquete   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi_4EE_alfa={}.dat'.format(alfa_4EE)
alfa_malo, E_Psi, x, Psi, dPsi = np.loadtxt(fichero_paquete, unpack=True, skiprows=4)
ax.hlines(y=E_Psi[0], xmin=x1, xmax=x2, lw=1.0, ls='-', color='k')
ax.hlines(y=E_Psi[0], xmin=x3, xmax=x4, lw=1.0, ls='-', color='k')
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (dPsi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right|^2$')
ax.plot(x, (Psi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right>$')
ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE))
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')
# ============
ax = axs[2][1]
# ============
alfa_4EE = 90
x1 = pcx1[12]
x2 = pcx2[12]
x3 = pcx3[12]
x4 = pcx4[12]
fichero_paquete   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi_4EE_alfa={}.dat'.format(alfa_4EE)
alfa_malo, E_Psi, x, Psi, dPsi = np.loadtxt(fichero_paquete, unpack=True, skiprows=4)
ax.hlines(y=E_Psi[0], xmin=x1, xmax=x2, lw=1.0, ls='-', color='k')
ax.hlines(y=E_Psi[0], xmin=x3, xmax=x4, lw=1.0, ls='-', color='k')
ax.plot(x, V, lw=1.3, color='gray')
ax.plot(x, (dPsi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right|^2$')
ax.plot(x, (Psi*multiplicador) + E_Psi[0], label=r'$\left| \psi \right>$')
ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE), xlabel=r'$x\ (\AA)$')
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)
ax.legend(loc='upper right')
# ============
ax = axs[3][1]
# ============
ax.clear()
ax.axis('off')

plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
# plt.show()
