# _____________________________________________________________________________
# *****************************************************************************
# Autor: José Antonio Quiñonero gris
# Fecha de creación: 3 de marzo de 2022
# *****************************************************************************
# -----------------------------------------------------------------------------

# Grafica para el oscilador con una perturbacion cuartica

# Librerias
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
from pylab import MaxNLocator

plt.style.use('mine')

# line cyclers adapted to colourblind people
from cycler import cycler
line_cycler   = (cycler(color=["#E69F00", "#56B4E9", "#009E73", "#0072B2", "#D55E00", "#CC79A7", "#F0E442"]) +
                 cycler(linestyle=["-", "--", "-.", ":", "-", "--", "-."]))
marker_cycler = (cycler(color=["#E69F00", "#56B4E9", "#009E73", "#0072B2", "#D55E00", "#CC79A7", "#F0E442"]) +
                 cycler(linestyle=["none", "none", "none", "none", "none", "none", "none"]) +
                 cycler(marker=["4", "2", "3", "1", "+", "x", "."]))
marker_line_cycler = (cycler(color=["#E69F00", "#56B4E9", "#009E73", "#0072B2", "#D55E00", "#CC79A7", "#F0E442"]) +
                      cycler(linestyle=["-", "-", "-", "-", "-", "-", "-"]) +
                      cycler(marker=["o", "^", "s", "v", "o", "^", "s"]))
marker_line_cycler_2 = (cycler(color=["#E69F00", "#56B4E9", "#009E73", "#0072B2", "#D55E00", "#CC79A7", "#F0E442"]) +
                      cycler(linestyle=["-", "--", "-", "--", "-", "--", "-"]) +
                      cycler(marker=["o", "^", "s", "v", "o", "^", "s"]))


plt.rc("axes", prop_cycle=marker_line_cycler)
# Para un solo axes
#ax.set_prop_cycle(line_cycler)


# *****************************************************************************
# INICIO
# *****************************************************************************
nombre_grafica = 'convergencia_E_vs_N.pdf'
# Creacion del dataframe
file1 = '../data/out-N_vs_W0.dat'
file3 = '../data/out-N_vs_W1.dat'
file5 = '../data/out-N_vs_W2.dat'
file7 = '../data/out-N_vs_W3.dat'

# Grafico
# width = 7.2*2/1.5
# height = 4.45/1.3
width = 7.2/1.5
height = 4.45*2/1.3
fig, ax = plt.subplots(2,figsize=(width, height))
# marker=["4", "2", "3", "1", "+", "x", "."]
grosor=2

# N, W0      = np.loadtxt(file1, unpack=True, skiprows=2)
# ax[0].plot(N,W0, lw=grosor, label=r'$W_0(\alpha)$'      )
# N, W1      = np.loadtxt(file3, unpack=True, skiprows=2)
# ax[1].plot(N,W1, lw=grosor, label=r'$W_5(\alpha)$'      )
# N, W2     = np.loadtxt(file5, unpack=True, skiprows=2)
# ax[1,0].plot(N,W2, lw=grosor, label=r'$W_{10}(\alpha)$'      )
# N, W3     = np.loadtxt(file7, unpack=True, skiprows=2)
# ax[1,1].plot(N,W3, lw=grosor, label=r'$W_{15}(\alpha)$'      )

N, W0      = np.loadtxt(file1, unpack=True, skiprows=2)
ax[0].plot(N,W0, lw=grosor, label=r'$E_0$'      )
N, W1      = np.loadtxt(file3, unpack=True, skiprows=2)
ax[0].plot(N,W1, lw=grosor, label=r'$E_1$'      )
N, W2     = np.loadtxt(file5, unpack=True, skiprows=2)
ax[1].plot(N,W2, lw=grosor, label=r'$E_2$'      )
N, W3     = np.loadtxt(file7, unpack=True, skiprows=2)
ax[1].plot(N,W3, lw=grosor, label=r'$E_3$'      )

ax[0].set_xlim(0, 15)
ax[0].set_ylim(min(W0)-(max(W0)-min(W0))/10,max(W0)+(max(W0)-min(W0))/10)
ax[1].set_xlim(0, 20)
ax[1].set_ylim(min(W2)-(max(W2)-min(W2))/10,max(W3)+(max(W3)-min(W3))/10)

ax[0].set(xlabel=r'$N$',  ylabel=r'$E\ (\mathrm{cm^{-1}})$')
ax[1].set(xlabel=r'$N$',  ylabel=r'$E\ (\mathrm{cm^{-1}})$')

# xa = axes.get_xaxis()
# xa.set_major_locator(MaxNLocator(integer=True))

ax[0].legend(fontsize=14)
ax[1].legend(fontsize=14)

ax[0].set_xticks(range(0,15,2))
ax[1].set_xticks(range(0,21,2))

# ax = plt.figure().gca()
# ax.xaxis.set_major_locator(MaxNLocator(integer=True))

# if archivo==file3:
#     handles, labels = ax.get_legend_handles_labels()
#     ax.legend(handles[::-1], labels[::-1], loc=(1.03,0.03))
# ax.text(0.9,0.95, r'$d=0.1$', horizontalalignment='center', verticalalignment='center', transform=ax.transAxes, bbox=dict(facecolor='none'))

plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
# plt.show()
