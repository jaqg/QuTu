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
fichero_puntos_corte   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-puntos_corte.dat'
N, xe, Vb = np.loadtxt(fichero_datos_1, unpack=True, skiprows=1)
alfa, E, x1, x2, x3, x4 = np.loadtxt(fichero_puntos_corte, unpack=True, skiprows=3)
# ===================
lista_alfa_4EE = [0, 10, 15, 20, 30, 40, 45, 50, 60, 70, 75, 80, 90]
for alfa_4EE,j in zip(lista_alfa_4EE, range(len(lista_alfa_4EE))):
    nombre_grafica = 'val_esp_x_alfa={}.pdf'.format(alfa_4EE)
    fichero_prob   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-val_esp_x_alfa={}.dat'.format(alfa_4EE)
    t, val_esp_x = np.loadtxt(fichero_prob, unpack=True, skiprows=4)
    #
    # GRAFICA
    #
    if alfa_4EE == 0:
        xmax = 50
    elif alfa_4EE == 10:
        xmax = 50
    elif alfa_4EE == 15:
        xmax = 50
    elif alfa_4EE == 20:
        xmax = 50
    elif alfa_4EE == 30:
        xmax = 50
    elif alfa_4EE == 40:
        xmax = 50
    elif alfa_4EE == 45:
        xmax = 25
    elif alfa_4EE == 50:
        xmax = 1
    elif alfa_4EE == 60:
        xmax = 1
    elif alfa_4EE == 70:
        xmax = 1
    elif alfa_4EE == 75:
        xmax = 1
    elif alfa_4EE == 80:
        xmax = 1
    elif alfa_4EE == 90:
        xmax = 1

    # xmax = 50

    xmin = 0
    ymax = 0.5
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
    ax.axhline(y=0,     xmin=xmin, xmax=xmax, lw=0.5, ls='-', color='gray')
    ax.axhline(y=x1[j], xmin=xmin, xmax=xmax, lw=0.5, ls='--', color='k')
    ax.axhline(y=x4[j], xmin=xmin, xmax=xmax, lw=0.5, ls='--', color='k')
    ax.axhline(y=xe,    xmin=xmin, xmax=xmax, lw=0.5, ls='--', color='gray')
    ax.axhline(y=-xe,   xmin=xmin, xmax=xmax, lw=0.5, ls='--', color='gray')
    ax.plot(t, val_esp_x, lw=1.3)
    ax.axhline(y=x2[j], xmin=xmin, xmax=xmax, lw=1.0, ls='--', color='k')
    ax.axhline(y=x3[j], xmin=xmin, xmax=xmax, lw=1.0, ls='--', color='k')
    ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE), xlabel=r'$t\ (\mathrm{ps})$', ylabel=r'$\left< x \right>_t\ (\mathrm{\AA})$')
    ax.set_xlim(xmin,xmax)
    ax.set_ylim(ymin,ymax)
    # ax.legend(loc='upper right')
    #
    plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
    # plt.show()
