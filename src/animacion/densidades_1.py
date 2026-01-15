# _____________________________________________________________________________
# *****************************************************************************
# Autor: José Antonio Quiñonero Gris
# Fecha de creación: 7 de febrero de 2022
# *****************************************************************************
# -----------------------------------------------------------------------------

# Animaciones de la particula en una caja unidimensional, bidimensional y
# tridimensional

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

# *****************************************************************************
# INICIO
nombre_animacion = 'ENE_1.mp4'
# *****************************************************************************

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
N, xe_A, Vb_cm = np.loadtxt(fichero_datos_1, unpack=True, skiprows=1)
xmin, xmax, dx = np.loadtxt(fichero_datos_2, unpack=True, skiprows=1)
x_A, V_cm = np.loadtxt(fichero_potencial, unpack=True, skiprows=2)
n_fich, Nconver, Econver, E_cm = np.loadtxt(fichero_energias, unpack=True, skiprows=1)
x_par, Phi0, Phi2, Phi4 = np.loadtxt(fichero_funciones_pares,
                                                       unpack=True, skiprows=2)
x_impar, Phi1, Phi3, Phi5 = np.loadtxt(fichero_funciones_impares,
                                                       unpack=True, skiprows=2)
x_dpar, dPhi0, dPhi2, dPhi4 = np.loadtxt(fichero_densidad_prob_pares,
                                                       unpack=True, skiprows=2)
x_dimpar, dPhi1, dPhi3, dPhi5 = np.loadtxt(fichero_densidad_prob_impares,
                                                       unpack=True, skiprows=2)
n_par, cPhi0, cPhi2, cPhi4  = np.loadtxt(fichero_coeficientes_par,
                                                       unpack=True, skiprows=1)
n_impar, cPhi1, cPhi3, cPhi5  = np.loadtxt(fichero_coeficientes_impar,
                                                       unpack=True, skiprows=1)
alfa_grad_arr, E_alfa, pcx1, pcx2, pcx3, pcx4 = np.loadtxt(fichero_puntos_corte,
                                                       unpack=True, skiprows=3)
mu, alfa_a0, alfa_A = np.loadtxt(fichero_masa_red_alfa,unpack=True, skiprows=1)

# Factores de conversión
RBOHR=0.529177210903      # angstrom
EUACM=2.1947463136320E+05 # hartrees -> cm-1
EHAJ=4.3597447222071E-18  # hartrees -> J
HP=6.62607015E-34         # Constante de Planck en J·s
CLUZ=29979245800          # Velocidad de la luz en cm/s
hbar_J=HP/(2*np.pi)       # Constante de Planck reducida en J·s
# Energías de los estados estacionarios en hartrees
E = E_cm/EUACM
V = V_cm/EUACM
x = x_A/RBOHR
E0 = E[0]
E1 = E[1]
E2 = E[2]
E3 = E[3]

# Parámetros xe y Vb en unidades atomicas
xe = xe_A/RBOHR
Vb = Vb_cm/EUACM

# Parametros a y b
a = Vb/xe**4
b = 2*Vb/xe**2
print(a, b)

# Puntos de corte
def Vb(a,b):
    res = b**2/(4*a)
    return res
def x1(n,a,b):
    res = np.sqrt(np.sqrt(b**2-4*Vb(a,b)*a+4*E[n]*a)/a+b/a)/np.sqrt(2)
    return res
def x2(n,a,b):
    res = np.sqrt(b/a-np.sqrt(b**2-4*Vb(a,b)*a+4*E[n]*a)/a)/np.sqrt(2)
    return res

# -- Definicion de constantes --
# Realizo el calculo en unidades atomicas, por lo que
hbar = 1                       # Constante de Planck reducida
m = mu                          # Masa de la particula
# Definicion de una constante 'alpha' para simplificar la formulacion
alpha = (6*m*a/hbar**2)**(1/3)
print("alpha =", alpha)
omega = hbar*alpha/m            # Momento angular: omega = (k/m)^(1/2)
k = m*omega**2                          # Constante de fuerza

n_barrera = 4

# -- Definicion de las funciones --
# Valores propios de la energia
def Eoa(n):
    # res = (n + 1/2) * hbar**2*alpha/m
    res = (n + 1/2) * hbar* omega
    return res

# Variable de desplazamiento xi
def xi(x):
    return np.sqrt(alpha) * x

# Constante de normalizacion
def N(n):
    return ( np.sqrt(alpha/np.pi) * (1/(2**n * factorial(n))) )**(1/2)

# Funcion exponencial a diferenciar
def diff_expo(x):
    return np.exp(-xi(x)**2)

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
    return np.exp(-1j * Eoa(n) * t/hbar)

# Funciones propias
def phi(n,x,t):
    return N(n) * expo(x) * Hv(n,x) * time_expo(n,t)

# Densidad de probabilidad
def dens_phi(n,x,t):
    return np.conj(phi(n,x,t)) * phi(n,x,t)

# -------------------------------
# --- FUNCIONES DE PRUEBA ---
limite = 0.01
multiplicador=1/200
# -------------------------------
def Phi0(x,t):
    res = 0
    for i in np.arange(0,len(cPhi0)):
        if abs(cPhi0[i])>limite:
            res = cPhi0[i] * phi(2*i,x,t) + res
    res = res
    return res
def dPhi0(x,t):
    res = np.conj(Phi0(x,t)) * (Phi0(x,t))
    return res

def Phi1(x,t):
    res = 0
    for i in np.arange(0,len(cPhi1)):
        if abs(cPhi1[i])>limite:
            res = cPhi1[i] * phi(2*i+1,x,t) + res
    res = res
    return res
def dPhi1(x,t):
    res = np.conj(Phi1(x,t)) * (Phi1(x,t))
    return res

def Phi2(x,t):
    res = 0
    for i in np.arange(0,len(cPhi2)):
        if abs(cPhi2[i])>limite:
            res = cPhi2[i] * phi(2*i,x,t) + res
    res = res
    return res
def dPhi2(x,t):
    res = np.conj(Phi2(x,t)) * (Phi2(x,t))
    return res

def Phi3(x,t):
    res = 0
    for i in np.arange(0,len(cPhi3)):
        if abs(cPhi3[i])>limite:
            res = cPhi3[i] * phi(2*i+1,x,t) + res
    res = res
    return res
def dPhi3(x,t):
    res = np.conj(Phi3(x,t)) * (Phi3(x,t))
    return res

def Phi4(x,t):
    res = 0
    for i in np.arange(0,len(cPhi4)):
        if abs(cPhi4[i])>limite:
            res = cPhi4[i] * phi(2*i,x,t) + res
    res = res
    return res
def dPhi4(x,t):
    res = np.conj(Phi4(x,t)) * Phi4(x,t)
    return res

c0 = 1/np.sqrt(2)
c1 = 1/np.sqrt(2)
E_tot = c0**2*E[0] + c1**2*E[1]

def Psi(x,t):
    res = c0 * Phi0(x,t) + c1 * Phi1(x,t)
    return res
def dPsi(x,t):
    res = np.conj(Psi(x,t)) * Psi(x,t)
    return res

# -----------------------------------------------------------------------------
# Datos
# -----------------------------------------------------------------------------
# x_vec = np.linspace(xmin, xmax, 100)
t0 = 0
dt = 1
nu = 1/(2 * np.pi) * np.sqrt(k/m)
T = 1/nu
T_frames = round(T/dt)

numero_frames = 3 * T_frames

# -----------------------------------------------------------------------------
# Animacion 1
# -----------------------------------------------------------------------------
xmin = -1.5
xmax = -xmin
ymin = 0
ymax = 0.02

# Creacion de la grafica
fig = plt.figure()
plt.axes()
ax = fig.gca()
# Creating color map
# my_cmap = plt.get_cmap('bone_r')
# Barra de color

# Funcion actualizar
def actualizar(i):
    t = t0 + (dt * i)

    y0   =  Psi(x,t).real*multiplicador + E_tot
    iy0  =  Psi(x,t).imag*multiplicador + E_tot
    dy0  = dPsi(x,t).real*multiplicador + E_tot

    # y1   =  Phi0(x,t).real  + E[0]
    # iy1  =  Phi0(x,t).imag  + E[0]
    # dy1  = dPhi0(x,t).real + E[0]

    ax.clear()
    # ax.axvline(x=0, lw=0.5,color='gray')

    ax.plot(x,y0,  label=r'$\mathrm{Re}\left\{ \left| \Psi\,(x,t) \right>\right\}$')
    # ax.plot(x,iy0,  label=r'$\mathrm{Imag}\left\{ \left| \Psi\,(x,t) \right>\right\}$')
    ax.plot(x,dy0,  label=r'$\left| \Psi\,(x,t) \right|^2$')

    # ax.plot(x,y1,  label=r'$\mathrm{Re}\left\{ \left| \Phi_0\,(x,t) \right>\right\}$')
    # ax.plot(x,iy1,  label=r'$\mathrm{Imag}\left\{ \left| \Phi_0\,(x,t) \right>\right\}$')
    # ax.plot(x,dy1,  label=r'$\left| \Phi_0\,(x,t) \right|^2$')

    ax.plot(x,V,color='gray',lw=1)

    # Niveles energia
    # Por debajo de la barrera
    for i in np.arange(0,n_barrera):
        ax.hlines(y = E[i], xmin=-x1(i,a,b), xmax=-x2(i,a,b), color='black', lw=1.0)
        ax.hlines(y = E[i], xmin=x2(i,a,b), xmax=x1(i,a,b), color='black', lw=1.0)
    # Por encima de la barrera
    for i in np.arange(n_barrera,len(E)):
        ax.hlines(y = E[i], xmin=-x1(i,a,b), xmax=x1(i,a,b), color='black', lw=1.0)

    plt.title('$t = {:.1f}$'.format(t))
    # plt.title(r'$t = {:.1f}$'.format(t))

    ax.set_xlabel(r'$x\ (a_0)$')
    ax.set_ylabel(r'$E\ (\mathrm{Ha})$')

    ax.set_xlim(xmin,xmax)
    ax.set_ylim(ymin,ymax)

    plt.legend(loc=(1.01, 0.5))

# Llamada a la funcion animacion
# animation.FuncAnimation(<figura>,
#                         <funcion a iterar>,
#                         <numero de iteraciones>,
#                         interval=<delay en ms> )
anim = animation.FuncAnimation(fig, actualizar, numero_frames,
                              interval=1, repeat=True, blit=False)

# Guardar el archivo
# anim.save(nombre_animacion, fps=30, extra_args=['-vcodec', 'libx264'])

plt.show()
# plt.close()
