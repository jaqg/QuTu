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
file2 = '../data_opt/out-N_vs_W0.dat'
file3 = '../data/out-N_vs_W5.dat'
file4 = '../data_opt/out-N_vs_W5.dat'
file5 = '../data/out-N_vs_W10.dat'
file6 = '../data_opt/out-N_vs_W10.dat'
file7 = '../data/out-N_vs_W15.dat'
file8 = '../data_opt/out-N_vs_W15.dat'

# Grafico
fig, axs = plt.subplots(2,2,figsize=(7.2,7.2))
# marker=["4", "2", "3", "1", "+", "x", "."]
grosor=1.2

N, W0      = np.loadtxt(file1, unpack=True, skiprows=2)
axs[0,0].plot(N,W0, lw=grosor, label=r'$W_0(\alpha)$'      )
N, W0_opt  = np.loadtxt(file2, unpack=True, skiprows=2)
axs[0,0].plot(N,W0_opt, lw=grosor, label=r'$W_0(\alpha_{\mathrm{opt.}})$'      )
N, W5      = np.loadtxt(file3, unpack=True, skiprows=2)
axs[0,1].plot(N,W5, lw=grosor, label=r'$W_5(\alpha)$'      )
N, W5_opt  = np.loadtxt(file4, unpack=True, skiprows=2)
axs[0,1].plot(N,W5_opt, lw=grosor, label=r'$W_5(\alpha_{\mathrm{opt.}})$'      )
N, W10     = np.loadtxt(file5, unpack=True, skiprows=2)
axs[1,0].plot(N,W10, lw=grosor, label=r'$W_{10}(\alpha)$'      )
N, W10_opt = np.loadtxt(file6, unpack=True, skiprows=2)
axs[1,0].plot(N,W10_opt, lw=grosor, label=r'$W_{10}(\alpha_{\mathrm{opt.}})$'      )
N, W15     = np.loadtxt(file7, unpack=True, skiprows=2)
axs[1,1].plot(N,W15, lw=grosor, label=r'$W_{15}(\alpha)$'      )
N, W15_opt = np.loadtxt(file8, unpack=True, skiprows=2)
axs[1,1].plot(N,W15_opt, lw=grosor, label=r'$W_{15}(\alpha_{\mathrm{opt.}})$'      )

axs[0,0].set_xlim(0, 14)
axs[0,0].set_ylim(min(W0)-(max(W0)-min(W0))/10,max(W0)+(max(W0)-min(W0))/10)
axs[0,1].set_xlim(3, 24)
axs[0,1].set_ylim(min(W5)-(max(W5)-min(W5))/10,max(W5)+(max(W5)-min(W5))/10)
axs[1,0].set_xlim(8, 38)
axs[1,0].set_ylim(min(W10)-(max(W10)-min(W10))/10,max(W10)+(max(W10)-min(W10))/10)
axs[1,1].set_xlim(10, 52)
axs[1,1].set_ylim(min(W15)-(max(W15)-min(W15))/10,max(W15)+(max(W15)-min(W15))/10)

axs[0,0].set(title=r'$n=0$',xlabel=r'$N$', ylabel=r'$E$ (Ha)')
axs[0,1].set(title=r'$n=5$',xlabel=r'$N$', ylabel=r'$E$ (Ha)')
axs[1,0].set(title=r'$n=10$',xlabel=r'$N$', ylabel=r'$E$ (Ha)')
axs[1,1].set(title=r'$n=15$',xlabel=r'$N$', ylabel=r'$E$ (Ha)')

axs[0,0].legend()
axs[0,1].legend()
axs[1,0].legend()
axs[1,1].legend()

# if archivo==file3:
#     handles, labels = ax.get_legend_handles_labels()
#     ax.legend(handles[::-1], labels[::-1], loc=(1.03,0.03))
# ax.text(0.9,0.95, r'$d=0.1$', horizontalalignment='center', verticalalignment='center', transform=ax.transAxes, bbox=dict(facecolor='none'))

plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
# plt.show()
