module eval_conductivity
	use conductivity_def
	
contains

subroutine conductivity(rho,T,chi,Gamma,eta,ionic,kappa,which_ee,K_components)
	use constants_def
	use nucchem_def, only: composition_info_type
	real(dp), intent(in) :: rho, T, chi, Gamma, eta
	type(composition_info_type), intent(in) :: ionic
	type(conductivity_components), intent(out) :: kappa
	integer, intent(in) :: which_ee
	logical, dimension(num_conductivity_channels), intent(in) :: K_components
	real(dp) :: nn,nion, nu, nu_c, kappa_pre, ne, kF, xF, eF, Gamma_e
	
	ne = rho/amu*ionic%Ye
	kF = (threepisquare*ne)**onethird
	xF = hbar*kF/Melectron/clight
	eF = sqrt(1.0+xF**2)
	Gamma_e = Gamma/ionic%Z53
	kappa_pre = onethird*pi**2*boltzmann**2*T*ne/Melectron/eF
	
	call clear_kappa
	nu_c = 0.0
	nu = 0.0
	if (K_components(icond_ee)) then 
		if (which_ee == icond_sy06) then
			nu_c = ee_SY06(ne,T)
		else
			nu_c = ee_PCY(ne,T)
		end if
		nu = nu + nu_c
		kappa% ee = kappa_pre/nu_c
	end if
	if (K_components(icond_ei))	then
		nu_c = eion(kF,Gamma_e,eta,ionic%Ye,ionic%Z,ionic%Z2,ionic%Z53,ionic%A)
		nu = nu + nu_c
		kappa% ei = kappa_pre/nu_c
	end if
	if (K_components(icond_eQ)) then
		nu_c = eQ(kF,T,ionic%Ye,ionic%Z,ionic%Z2,ionic%A,ionic%Q)
		nu = nu + nu_c
		if (ionic%Q > 1.0e-8) then
			kappa% eQ = kappa_pre/nu_c
		else
			kappa% eQ = -1.0
		end if
	end if
	if (K_components(icond_sf) .and. ionic% Yn > 0.0) then
		nn = rho*ionic% Yn/(1.0-chi)/Mneutron / density_n
		nion = (1.0-ionic%Yn)*rho/Mneutron/ionic% A /density_n
		kappa% sf =  sPh(nn,nion,T,ionic)
	end if
	kappa% total = kappa_pre/nu + kappa% sf
	
	contains
	subroutine clear_kappa()
		kappa% total = 0.0
		kappa% ee  = 0.0
		kappa% ei = 0.0
		kappa% eQ = 0.0
		kappa% sf = 0.0		
	end subroutine clear_kappa
end subroutine conductivity

function ee_PCY(ne,T) result(nu)
	! fmla. from Potekhin, Chabrier, and Yakovlev (1997)
	use constants_def
	real(dp), intent(in) :: ne, T
	real(dp) :: nu
	real(dp) :: yfac
	real(dp) :: mec2
	real(dp) :: eefac
	real(dp) :: befac
	real(dp) :: onesixth = 1.0/6.0
	real(dp) :: plasma_theta, kF
	real(dp) :: x, eF, beta, b2, be3, y, lJ, llJ, J0,J1,J2,J

	yfac = sqrt(4.0*finestructure/pi)
	mec2 = Melectron*clight**2
	eefac = 1.5*finestructure**2*mec2/pi**3/hbar
	befac = (finestructure/pi)**1.5
	
	kF = (3.0*pi**2*ne)**onethird
	x = kF*hbar/Melectron/clight
	eF = sqrt(1.0+x**2)
	beta = x/eF
	b2 = beta**2
	be3 = befac/beta**1.5
	plasma_theta = boltzmann*T/mec2
	y = yfac*x**1.5/plasma_theta/sqrt(ef)
	lJ = 1.0 + (2.810-0.810*b2)/y
	llj = log(lJ)
	J0 = onethird/(1.0+0.07414*y)**3
	J1 = J0*llJ + onesixth*pi**5*y/(13.91+y)**4
	J2 = 1.0+0.4*(3.0+1.0/x**2)/x**2
	J = y**3 * J1*J2
	
	nu = eefac*plasma_theta**2*J/eF/be3
end function ee_PCY


function ee_SY06(ne,T) result(nu)
	! uses fmla of Shternin & Yakovlev (2006). Checked against routine courtesy of D. Page.
	!
	use constants_def
	real(dp), intent(in) :: ne, T
	real(dp) :: nu
	real(dp) :: nu_pre
	real(dp) :: Tp_pre
	real(dp) :: Il, It, Ilt, I
	real(dp) :: At, Ct, Ct1, Ct2, Alt, Blt, Clt, Clt1, Clt2
	real(dp) :: u2, u3, u4, tu
	real(dp) :: kF, Tp, theta, xF, eF, u, mstar

    nu_pre = 36.0*finestructure**2*hbar**2*clight/pi/boltzmann/Melectron
    Tp_pre = hbar*sqrt(4.0*pi*finestructure*hbar*clight/Melectron)/boltzmann

	kF = (threepisquare*ne)**onethird
	xF = hbar*kF/Melectron/clight
	eF = sqrt(1.0+xF**2)
	u = xF/eF
	Tp = Tp_pre*sqrt(ne/eF)
	theta = sqrt(3.0)*Tp/T

	u2 = u**2
	u3 = u**3
	u4 = u**4
	tu = theta*u
	At = 20.0+450.0*u3
	Ct1 = 0.05067+0.03216*u2
	Ct2 = 0.0254+0.04127*u4
	Ct = At*exp(Ct1/Ct2)

	Alt = 12.2 + 25.2*u3
	Blt = 1.0-0.75*u
	Clt1 = 0.123636+0.016234*u2
	Clt2 = 0.0762+0.05714*u4
	Clt = Alt*exp(Clt1/Clt2)

	Il = (1.0/u)*(0.1587 - 0.02538/(1.0+0.0435*theta))*log(1.0+128.56/theta/(37.1 + theta*(10.83 + theta)))
	It = u3*(2.404/Ct + (Ct2-2.404/Ct)/(1.0+0.1*tu))*log(1.0 + Ct/tu/(At + tu))
	Ilt = u*(18.52*u2/Clt + (Clt2-18.2*u2/Clt)/(1.0+0.1558*theta**Blt)) &
			& *log(1.0 + Clt/(Alt*theta + 10.83*tu**2 + tu**(8.0/3.0)))

	I = Il + It + Ilt
	nu = nu_pre*ne*I/eF/T
end function ee_SY06

function eion(kF,Gamma_e,eta,Ye,Z,Z2,Z53,A) result(nu)
	! implements fmla. of Baiko et al. (1999)
	use constants_def
	real(dp), intent(in) :: kF, Gamma_e, eta, Ye, Z, Z2, Z53, A
	real(dp) :: nu
	! interface
	! 	function eone(z)
	! 		real(dp)(kind=8) :: z, eone
	! 	end function eone
	! end interface
	real(dp), parameter :: um1 = 2.8, um2 = 12.973, onesixth = 1.0/6.0, fourthird = 4.0*onethird
	real(dp) :: electroncompton
	real(dp) :: aB
	real(dp) :: eifac
	real(dp) :: kF2,x,eF,Gamma,v,v2,kTF2,eta02,aei,qD2,beta,qi2,qs2
	real(dp) :: Gs,Gk0,Gk1,GkZ,Gk,a0,D1,D,s,w1,w,sw,fac
	real(dp) :: L1,L2,Lei
	
    electroncompton = hbar/Melectron/clight
    aB = electroncompton/finestructure
    eifac = fourthird*clight*finestructure**2/electroncompton/pi
    
	kF2 = kF**2
	x = electroncompton*kF
	eF = sqrt(1.0+x**2)
	v = x/eF
	v2 = v**2
	Gamma = Gamma_e*Z53
	s = finestructure/pi/v
	kTF2 = 4.0*s*kF2
	eta02 = (0.19/Z**onesixth)**2
	aei = (4.0/9.0/pi)**onethird * kF
	qD2 = 3.0*Gamma_e*aei**2 * Z2/Z
	beta = pi*finestructure*Z*v

	qi2 = qD2*(1.0+0.06*Gamma)*exp(-sqrt(Gamma))
	qs2 = (qi2+kTF2)*exp(-beta)
	
	Gs = eta/sqrt(eta**2+eta02)*(1.0+0.122*beta**2)
	Gk0 = 1.0/(eta**2+0.0081)**1.5
	Gk1 = 1.0 + beta*v**3
	GkZ = 1.0-1.0/Z
	Gk = Gs + 0.0105*GkZ*Gk1*Gk0*eta
	
	a0 = 4.0*kF2/qD2/eta
	D1 = exp(-9.1*eta)
	D = exp(-a0*um1*D1*0.25)
	
	w1 = 1.0+onethird*beta
	w = 4.0*um2*kF2/qD2*w1
	
	sw = s*w
	fac = exp(sw)*(eone(sw)-eone(sw+w))
	
	L1 = 0.5*(log(1.0+1.0/s) + (1.0-exp(-w))*s/(s+1.0) - fac*(1.0+sw))
	L2 = 0.5*(1.0-(1.0-exp(-w))/w + s*(s/(1.0+s)*(1.0-exp(-w))  &
				& - 2.0*log(1.0+1.0/s) 	+fac*(2.0+sw)))
	Lei = (Z2/A)*(L1-v2*L2)*Gk*D
	nu = eifac*eF*Lei*A/Z
	
	contains
	function eone(z)
		real(dp), intent(in) :: z
		real(dp) :: eone
		
		real(dp), parameter :: a0 = 0.1397, a1 = 0.5772, a2 = 2.2757
		real(dp) :: z2, z3, z4
		z2 = z*z; z3 = z2*z; z4 = z2*z2
		eone = exp(-z4/(z3+a0))*(log(1.0+1.0/z)-a1/(1.0+a2*z2))
	end function eone
end function eion

function eQ(kF,T,Ye,Z,Z2,A,Q) result (nu)
	! impurity scattering: Iton (1994), also Potekhin, priv. communication
	use constants_def
	real(dp), intent(in) :: kF,T,Ye,Z,Z2,A,Q
	real(dp) :: nu
	real(dp) :: dZ2,kF2,x,gamma,v2,v,qs2,s,L1,L
	real(dp) :: electron_compton, mec2
	real(dp) :: fac

    electron_compton = hbar/Melectron/clight
    mec2 = Melectron*clight**2
    fac = 4.0*onethird*clight*finestructure**2/electron_compton/pi
    
	dZ2 = Q/A
	kF2 = kF**2
	x = electron_compton*kF
	gamma = sqrt(1.0+x**2)
	v = x/gamma
	v2 = v**2
	s = finestructure/pi/v
	qs2 = 4.0*kF2*s
	
	L1 = 1.0+4.0*v2*s
	L = 0.5*(L1*log(1.0+1.0/s) - v2 -1.0/(s+1.0) - v2*s/(1.0+s))
	nu = fac*gamma*dZ2*L*A/Z
end function eQ

function sPh(nn, nion, temperature, ionic)
	! neutron superfluid phonon conductivity, following Aguilera et al. (2009), PRL
	!
	use nucchem_def, only: composition_info_type
	use constants_def
	real(dp), intent(in) :: nn, nion, temperature
	type(composition_info_type), intent(in) :: ionic
	real(dp) :: sPh
	real(dp) :: K_n
	real(dp) :: etwo
	real(dp) :: Mu_n
	real(dp), parameter :: anl = 10.0
	real(dp) :: T,ai,kFn,kFe,vs,Cv,omega_p,TUm,anlt,gmix,cs,qTFe,alpha,tau_lph,wt
	real(dp) :: Llphn,Llphu,Llph,Lsph,fu,omega

	K_n = boltzmann*clight*fm_to_cm/(hbarc_n*fm_to_cm)**3
	etwo = finestructure*hbarc_n
	Mu_n = amu*clight2*ergs_to_mev
	
	! convert to nuclear units
	T = temperature*boltzmann*ergs_to_mev
	ai = (3.0/fourpi/nion)**onethird
	kFn = (threepisquare*nn)**onethird
	kFe = (threepisquare*nion*ionic%Z)**onethird
	! phonon speed
	vs = hbarc_n*kFn/Mn_n/sqrt(3.0)
	! specific heat, phonon gas
	Cv = 2.0*pi**2*T**3/15.0/vs**3
	! ion plasma freq
	omega_p = sqrt(fourpi*etwo*ionic%Z2*nion/ionic%A/Mu_n)
	! Thomas-Fermi wavevector
	qTFe = sqrt(4.0*finestructure/pi)*kFe
	! sound speed
	cs = omega_p/qTFe
	alpha = cs/vs
	! mixing parameter
	anlt = anl/(1.0+0.4*kFn*anl + 0.5*2.0*anl*kFn**2)
	gmix = 2.0*anlt*hbarc_n*sqrt(nion*kFn/ionic%A/Mu_n**2)
	! Umklapp temperature
	TUm = onethird*etwo*omega_p*(ionic% Z)**onethird
	! thermal phonon frequency
	omega = 3.0*T/hbarc_n
	! interpolation fmla.
	fu = exp(-TUm/T)
	! mean-free path, normal; fu interpolates to Umklapp scattering
	Llphn = 2.0/pi/omega
	Llphu = 100.0*ai
	Llph = 1.0/(fu/Llphu + (1.0-fu)/Llphn)
	tau_lph = Llph/cs
	wt = tau_lph*omega
	Lsph = Llph*(vs/gmix)**2*(1.0+(1.0-alpha**2)**2 * wt**2)/alpha/wt**2
	sPh = onethird*Cv*vs*Lsph * K_n
end function sPh

end module eval_conductivity
