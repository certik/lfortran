program traits_component_allocatable_01
    use traits_component_allocatable_01_client_m, only: Client
    implicit none
    type(Client) :: c

    call c%run()
    print '(a)', "typed allocation of a derived type with a trait component"
end program traits_component_allocatable_01
