# _____________________________________________________________________________
# *****************************************************************************
# Autor: José Antonio Quiñonero Gris
# Fecha de creación: 7 de febrero de 2022
# *****************************************************************************
# -----------------------------------------------------------------------------

# Animaciones de un paquete de ondas en un potencial de doble pozo simétrico
# aplicado al movimiento de inversion de la molécula de amoníaco

# Librerias
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import axes3d
import matplotlib.animation as animation
from matplotlib import cm
from math import factorial
from scipy.special import hermite

# Usar mi estilo para las graficas
plt.style.use('mine')

# =============================================================================
# --- INICIO ---
# =============================================================================

# Ficheros de datos
fichero_datos_1                = '../data/in-doble_pozo_NH3.dat'
fichero_datos_2                = '../data/in-potencial.dat'
fichero_potencial              = '../data/out-potencial_cm-1.dat'
fichero_energias               = '../data/out-conver_energias_cm-1.dat'
fichero_funciones_pares        = '../data/out-funciones_pares_A.dat'
fichero_funciones_impares      = '../data/out-funciones_impares_A.dat'
fichero_densidad_prob_pares    = '../data/out-densidad_prob_pares_A.dat'
fichero_densidad_prob_impares  = '../data/out-densidad_prob_impares_A.dat'
fichero_coeficientes_par       = '../data/out-coeficientes_par.dat'
fichero_coeficientes_impar     = '../data/out-coeficientes_par.dat'
fichero_puntos_corte           = '../data/out-puntos_corte.dat'
fichero_masa_red_alfa          = '../data/out-masa_red_alfa.dat'
# Apertura de ficheros, lectura de datos y definición de variables
N, xe, Vb = np.loadtxt(fichero_datos_1, unpack=True, skiprows=1)
xmin, xmax, dx = np.loadtxt(fichero_datos_2, unpack=True, skiprows=1)
x_A, V = np.loadtxt(fichero_potencial, unpack=True, skiprows=2)
n_fich, Nconver, Econver, E = np.loadtxt(fichero_energias, unpack=True, skiprows=1)
# x, Phi0, Phi2, Phi4 = np.loadtxt(fichero_funciones_pares,
#                                                        unpack=True, skiprows=2)
# x, Phi1, Phi3, Phi5 = np.loadtxt(fichero_funciones_impares,
#                                                        unpack=True, skiprows=2)
# x, dPhi0, dPhi2, dPhi4 = np.loadtxt(fichero_densidad_prob_pares,
#                                                        unpack=True, skiprows=2)
# x, dPhi1, dPhi3, dPhi5 = np.loadtxt(fichero_densidad_prob_impares,
                                                       # unpack=True, skiprows=2)
n_par, cPhi0, cPhi2, cPhi4  = np.loadtxt(fichero_coeficientes_par,
                                                       unpack=True, skiprows=1)
n_impar, cPhi1, cPhi3, cPhi5  = np.loadtxt(fichero_coeficientes_impar,
                                                       unpack=True, skiprows=1)
alfa_grad, E_alfa, pcx1, pcx2, pcx3, pcx4 = np.loadtxt(fichero_puntos_corte,
                                                       unpack=True, skiprows=3)
mu, alfa_a0, alfa_A = np.loadtxt(fichero_masa_red_alfa,unpack=True, skiprows=1)
# Factores de conversión
RBOHR=0.529177210903      # angstrom
EUACM=2.1947463136320E+05 # hartrees -> cm-1
EHAJ=4.3597447222071E-18  # hartrees -> J
HP=6.62607015E-34         # Constante de Planck en J·s
CLUZ=29979245800          # Velocidad de la luz en cm/s
hbar_J=HP/(2*np.pi)       # Constante de Planck reducida en J·s
# Energías de los estados estacionarios en J
E0 = E[0]*HP*CLUZ
E1 = E[1]*HP*CLUZ
E2 = E[2]*HP*CLUZ
E3 = E[3]*HP*CLUZ

# Parámetros xe y Vb en unidades atomicas
# xe = xe/RBOHR
# Vb = Vb/EUACM

# Puntos de corte
def x1c(n):
    res = np.sqrt(np.sqrt(E[n]*Vb)/Vb+1)*xe
    return res
def x2c(n):
    res = np.sqrt(1-np.sqrt(E[n]*Vb)/Vb)*xe
    return res

# Valores propios de la energia
def Eoa(n):
    res = (n + 1/2) * alfa_a0/mu # Resultado en unidades atomicas
    return res*EHAJ # Resultado en J
# Variable de desplazamiento xi
def xi(x):
    return np.sqrt(alfa_A) * x
# Constante de normalizacion
def N(n):
    res = ( np.sqrt(alfa_A/np.pi) * (1/(2**n * factorial(n))) )**(1/2)
    return res
# Funcion exponencial
def expo(x):
    return np.exp(-(xi(x)**2)/2)
# Polinomios de Hermite
def Hv(n,x):
    herm = hermite(n)
    P_v = herm(x)
    return P_v
# Componente temporal de funciones
def time_expo(n,t):
    return np.exp(-1j * Eoa(n) * t/hbar_J)
# Funciones propias
def phi(n,x,t):
    return N(n) * expo(x) * Hv(n,x) * time_expo(n,t)
# Densidad de probabilidad
def dens_phi(n,x,t):
    return np.conj(phi(n,x,t)) * phi(n,x,t)

### -- FUNCIONES DE PRUEBA -- ###
limite_coefs = 0.01
def Phi0(x,t):
    res = 0
    for i in np.arange(0,len(cPhi0)):
        if abs(cPhi0[i])>limite_coefs:
            # print("i =", i, "factorial(i) =", factorial(i))
            res = cPhi0[i] * phi(2*i,x,t) + res
    res = res
    return res
def dPhi0(x,t):
    res = np.conj(Phi0(x,t)) * (Phi0(x,t))
    return res
#
def Phi1(x,t):
    res = 0
    for i in np.arange(0,len(cPhi1)):
        if abs(cPhi1[i])>limite_coefs:
            # print("i =", i, "factorial(i) =", factorial(i))
            res = cPhi1[i] * phi(2*i+1,x,t) + res
    res = res
    return res
def dPhi1(x,t):
    res = np.conj(Phi1(x,t)) * (Phi1(x,t))
    return res
#
def Phi2(x,t):
    res = 0
    for i in np.arange(0,len(cPhi2)):
        if abs(cPhi2[i])>limite_coefs:
            # print("i =", i, "factorial(i) =", factorial(i))
            res = cPhi2[i] * phi(2*i,x,t) + res
    res = res
    return res
def dPhi2(x,t):
    res = np.conj(Phi2(x,t)) * (Phi2(x,t))
    return res
#
def Phi3(x,t):
    res = 0
    for i in np.arange(0,len(cPhi3)):
        if abs(cPhi3[i])>limite_coefs:
            # print("i =", i, "factorial(i) =", factorial(i))
            res = cPhi3[i] * phi(2*i+1,x,t) + res
    res = res
    return res
def dPhi3(x,t):
    res = np.conj(Phi3(x,t)) * (Phi3(x,t))
    return res
#
def Phi4(x,t):
    res = 0
    for i in np.arange(0,len(cPhi4)):
        if abs(cPhi4[i])>limite_coefs:
            # print("i =", i, "factorial(i) =", factorial(i))
            res = cPhi4[i] * phi(2*i,x,t) + res
    res = res
    return res
def dPhi4(x,t):
    res = np.conj(Phi4(x,t)) * Phi4(x,t)
    return res

# Coeficientes (amplitudes) de los estados no estacionarios
def c0(alfa):
    res = 1/np.sqrt(2) * np.cos(alfa*np.pi/180)
    return res
def c1(alfa):
    res = 1/np.sqrt(2) * np.cos(alfa*np.pi/180)
    return res
def c2(alfa):
    res = 1/np.sqrt(2) * np.sin(alfa*np.pi/180)
    return res
def c3(alfa):
    res = 1/np.sqrt(2) * np.sin(alfa*np.pi/180)
    return res

# Creacion del paquete de ondas
# NOTA: tiempo en picosegundos (ps)
def Psi(x,t,alfa):
    res = c0(alfa) * Phi0(x,t*1E-12) + \
          c1(alfa) * Phi1(x,t*1E-12) + \
          c2(alfa) * Phi2(x,t*1E-12) + \
          c3(alfa) * Phi3(x,t*1E-12)
    return res
def dPsi(x,t,alfa):
    res = np.conj(Psi(x,t,alfa)) * Psi(x,t,alfa)
    return res

# -----------------------------------------------------------------------------
# Datos
# -----------------------------------------------------------------------------
xmax = 0.75
xmin = -xmax
ymin = 0
ymax = 2500
x_vec = np.linspace(xmin, xmax, 200)
#
alfa_ind = 12
alfa = alfa_grad[alfa_ind]
energia = E_alfa[alfa_ind]
x1 = pcx1[alfa_ind]
x2 = pcx2[alfa_ind]
x3 = pcx3[alfa_ind]
x4 = pcx4[alfa_ind]
#
t0 = 0
if alfa_ind>=6:
    dt = 1/1000
    tf = 0.5
else:
    dt = 1/30
    tf = 25
# nu = 1/(2 * np.pi) * np.sqrt(k/m)
# T = 1/nu
# T_frames = round(T/dt)
numero_frames = round((tf - t0)/dt)
# -----------------------------------------------------------------------------
# Grafica individual
multiplicador=5000
multiplicador=200
# -----------------------------------------------------------------------------
nombre_grafica = 'graficas/grafica_ejemplo.pdf'
#
#fig, ax = plt.subplots()
##
# # Niveles de energia
#for i in np.arange(0,len(E)):
#    if E[i]<=Vb:
#        ax.hlines(y = E[i], xmin=-x1c(i), xmax=-x2c(i), color='gray', lw=1.0)
#        ax.hlines(y = E[i], xmin=x2c(i), xmax=x1c(i), color='gray', lw=1.0)
#    else:
#        ax.hlines(y = E[i], xmin=-x1c(i), xmax=x1c(i), color='gray', lw=1.0)
##
#ax.plot(x_A, V, label=r'$V\,(x)$', lw=1.3, color='gray')

#t = 20
#y  = dPsi(x_vec,t,alfa).real*multiplicador + energia
#y2 = Psi(x_vec,t,alfa).real*multiplicador + energia
#ax.plot(x_vec, y,  label=r'$\left| \Psi(t) \right|^2$')
#ax.plot(x_vec, y2, label=r'$\left| \Psi(t) \right>$')
##
#ax.set(xlabel=r'$x\ (\AA)$', ylabel=r'$E\ (\mathrm{cm^{-1}})$')
#ax.set_xlim(xmin,xmax)
#ax.set_ylim(ymin,ymax)
#ax.legend(loc='upper right')
##
#plt.savefig(nombre_grafica, transparent='True', bbox_inches='tight')
# plt.show()
#
# -----------------------------------------------------------------------------
# Animacion 1
# -----------------------------------------------------------------------------
#
# Creacion de la grafica
fig = plt.figure()
plt.axes()
ax = fig.gca()
# Funcion actualizar
def actualizar(i):
    t = t0 + (dt * i)
    #
    y1 = dPsi(x_vec,t,alfa).real*multiplicador + energia
    y2 = Psi(x_vec,t,alfa).real*multiplicador + energia
    # y3 = Psi(x_vec,t,alfa).imag*multiplicador + energia
    #
    ax.clear()
    # ax.axvline(x=0, lw=0.5,color='gray')
    #
    ax.plot(x_vec,y1,  label=r'$\left| \Psi\,(x,t) \right|^2$')
    ax.plot(x_vec,y2,  label=r'$\mathrm{Re}\left\{ \left| \Psi\,(t) \right>\right\}$')
    # ax.plot(x,y3,  label=r'$\mathrm{Imag}\left\{ \left| \Psi\,(x,t) \right>\right\}$')
    #
    ax.plot(x_A,V,label=r'$V\,(x)$',color='gray',lw=1)
    #
    # Niveles de energia
    for i in np.arange(0,len(E)):
        if E[i]<=Vb:
            ax.hlines(y = E[i], xmin=-x1c(i), xmax=-x2c(i), color='gray', lw=1.0)
            ax.hlines(y = E[i], xmin=x2c(i), xmax=x1c(i), color='gray', lw=1.0)
        else:
            ax.hlines(y = E[i], xmin=-x1c(i), xmax=x1c(i), color='gray', lw=1.0)
    ax.hlines(y = energia, xmin=x1, xmax=x2, color='black', lw=1.3)
    ax.hlines(y = energia, xmin=x3, xmax=x4, color='black', lw=1.3)
    #
    plt.title(r'$\alpha = {}$,'.format(alfa) + '\t' + r'$t = {:.4f}$ ps'.format(t))
    ## plt.title(r'$t = {:.1f}$'.format(t))
    #
    ax.set_xlabel(r'$x\ (\AA)$')
    ax.set_ylabel(r'$E\ (\mathrm{cm^{-1}})$')
    #
    ax.set_xlim(xmin,xmax)
    ax.set_ylim(ymin,ymax)
    #
    plt.legend(loc='upper right')
    #
# Llamada a la funcion animacion
# animation.FuncAnimation(<figura>,
#                         <funcion a iterar>,
#                         <numero de iteraciones>,
#                         interval=<delay en ms> )
anim = animation.FuncAnimation(fig, actualizar, numero_frames,
                              interval=1, repeat=True, blit=False)

# Guardar el archivo
# anim.save('videos/wavepacket_1_alfa={}.mp4'.format(alfa), fps=30, extra_args=['-vcodec', 'libx264'])

plt.show()
# # plt.close()
