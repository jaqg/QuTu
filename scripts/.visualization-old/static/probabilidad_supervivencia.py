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
for alfa_4EE,j in zip(lista_alfa_4EE, range(len(lista_alfa_4EE))):
    nombre_grafica = 'prob_sup_alfa={}.pdf'.format(alfa_4EE)
    fichero_prob   = '/home/jose/Documents/Universidad/TFG/practicas_QFA/doble_pozo_NH3/data/out-prob_sup_alfa={}.dat'.format(alfa_4EE)
    t, Ps = np.loadtxt(fichero_prob, unpack=True, skiprows=4)
    #
    # GRAFICA
    #
    if alfa_4EE == 0:
        xmax = 50
    elif alfa_4EE == 10:
        xmax = 1
    elif alfa_4EE == 20:
        xmax = 1
    elif alfa_4EE == 30:
        xmax = 1
    elif alfa_4EE == 40:
        xmax = 1
    elif alfa_4EE == 45:
        xmax = 1
    elif alfa_4EE == 50:
        xmax = 1
    elif alfa_4EE == 60:
        xmax = 1
    elif alfa_4EE == 70:
        xmax = 1
    elif alfa_4EE == 80:
        xmax = 1
    elif alfa_4EE == 90:
        xmax = 1

    xmin = 0
    ymax = 1
    ymin = 0
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
    ax.axhline(y=0, xmin=xmin, xmax=xmax, lw=1.0, ls='-', color='k')
    # ax.plot(t, Ps)
    ax.plot(t, Ps, lw=1.3)
    ax.set(title=r'$\alpha = {:.0f}^\circ$'.format(alfa_4EE), xlabel=r'$t\ (\mathrm{ps})$', ylabel=r'$P_s(t)$')
    ax.set_xlim(xmin,xmax)
    ax.set_ylim(ymin,ymax)
    # ax.legend(loc='upper right')
    #
    plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
    # plt.show()
