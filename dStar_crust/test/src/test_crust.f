program test_crust
    use constants_def, only: dp
    use constants_lib
    use nucchem_def
    use nucchem_lib
    use superfluid_lib
    use dStar_eos_lib
    use dStar_crust_def
    use dStar_crust_lib
    
    integer, parameter :: Ntrial = 20
    integer :: i, ierr
    real(dp), dimension(Ntrial) :: lgP, lgRho, Xneut, lgNb, dlgRho, dlgNb
    real(dp), dimension(:,:), allocatable :: Yion
    integer, dimension(:), allocatable :: charged_ids
    integer :: ncharged
    type(composition_info_type), dimension(Ntrial) :: ion_info
    integer :: eos_handle, Niso
    real(dp) :: Tref
    
    call constants_init('',ierr)
    call check_okay('constants_init',ierr)
    
    call nucchem_init('../../data',ierr)
    call check_okay('nucchem_init',ierr)
	
    call sf_startup('../../data',ierr)
    call check_okay('sf_startup',ierr)
	
    call sf_load_gaps('ns','gc','t72',ierr)
    call check_okay('sf_load_gaps',ierr)
	
    call dStar_eos_startup('../../data')
    call check_okay('dStar_eos_startup',ierr)
	
    eos_handle = alloc_dStar_eos_handle(ierr)
    call check_okay('alloc_dStar_eos_handle',ierr)
    
    ! switch off the warnings about quantum effects
    call dStar_eos_set_controls(eos_handle,suppress_warnings=.TRUE.)
    
    call dStar_crust_startup('../../data',ierr)
    call check_okay('dStar_atm_startup',ierr)
    
    Tref = 1.0d8
    call dStar_crust_load_table('hz90',eos_handle, Tref,ierr)
    call check_okay('dStar_crust_load_table',ierr)
        
    lgP = [(26.5+5.0*real(i-1,dp)/real(Ntrial-1,dp),i=1,Ntrial)]
    
    do i = 1,Ntrial
        call dStar_crust_get_results(lgP(i),lgRho(i),dlgRho(i),lgNb(i),dlgNb(i),ierr)
        call check_okay('dStar_crust_get_results',ierr)
        write(*,'(5(f9.5,tr2))') lgP(i),lgRho(i),dlgRho(i),lgNb(i),dlgNb(i)
    end do
    
    Niso = dStar_crust_get_composition_size()
    allocate(Yion(Niso,Ntrial),charged_ids(Niso))
    
    call dStar_crust_get_composition(lgP,ncharged,charged_ids,Yion,Xneut,ion_info,ierr)
    call check_okay('dStar_crust_get_composition',ierr)

    do i = 1,Ntrial
        write(*,'(f9.5,tr2,2(f7.4,tr2),2(f6.2,tr2),2(f7.4,tr2),f7.2)') lgP(i),Xneut(i),maxval(Yion(1:ncharged,i)), &
        &   ion_info(i)% Z, ion_info(i)% A, ion_info(i)% Ye, ion_info(i)% Yn, ion_info(i)%Q
    end do
    
    call dStar_crust_shutdown
    call sf_shutdown
    call nucchem_shutdown

contains
	subroutine check_okay(msg,ierr)
		use iso_fortran_env, only : error_unit
		character(len=*), intent(in) :: msg
		integer, intent(inout) :: ierr
		if (ierr /= 0) then
			write (error_unit,*) trim(msg)//': ierr = ',ierr
			if (ierr < 0) stop
		end if
	end subroutine check_okay

end program test_crust
