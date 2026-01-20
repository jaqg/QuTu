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

# ===================
lista_alfa_4EE = [0, 10, 15, 20, 30, 40, 45, 50, 60, 70, 75, 80, 90]
for alfa_4EE in lista_alfa_4EE:
    print(alfa_4EE)
    nombre_grafica = 'paquetes_alfa={}.pdf'.format(alfa_4EE)
    fichero_paquete   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-psi_4EE_alfa={}.dat'.format(alfa_4EE)
    alfa_malo, E_Psi, x, Psi, dPsi = np.loadtxt(fichero_paquete, unpack=True, skiprows=4)
    #
    fichero_datos_1   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/in-doble_pozo_NH3.dat'
    #
    N, xe, Vb      = np.loadtxt(fichero_datos_1,   unpack=True, skiprows=1)
    #
    RBOHR=0.529177210903      # angstrom
    EUACM=2.1947463136320E+05 # hartrees -> cm-1
    #
    # xe = xe/RBOHR
    # Vb = Vb/EUACM
    #
    def x1(n):
        res = np.sqrt(np.sqrt(E[n]*Vb)/Vb+1)*xe
        return res
    def x2(n):
        res = np.sqrt(1-np.sqrt(E[n]*Vb)/Vb)*xe
        return res
    #
    # GRAFICA
    #
    xmax = 0.75
    xmin = -xmax
    ymax = 6.5
    ymin = -ymax
    #
    # width as measured in inkscape
    width = 15.922
    width = 7.2 * 1.5
    width = 5.4
    # height = width / 1.618
    height = 4.45
    #
    fig, ax = plt.subplots(figsize=(width, height))
    #
    # ==========================================
    ax.axvline(x=-xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
    ax.axvline(x=xe, ymin=ymin, ymax=ymax, lw=1.0, ls='--', color='gray')
    ax.axvline(x=0, ymin=ymin, ymax=ymax, lw=1.0, ls='-', color='k')
    ax.axhline(y=0, xmin=xmin, xmax=xmax, lw=1.0, ls='-', color='k')
    ax.plot(x, dPsi, label=r'$\left| \Psi \right|^2$')
    ax.plot(x, Psi, label=r'$\left| \Psi \right>$')
    ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE), xlabel=r'$x\ (\AA)$')
    ax.set_xlim(xmin,xmax)
    ax.set_ylim(ymin,ymax)
    ax.legend(loc='upper right')
    #
    plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
    # plt.show()
