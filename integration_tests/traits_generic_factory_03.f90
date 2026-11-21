! A client of the separately compiled container modules of
! traits_generic_factory_03_lib: it instantiates their generic helpers, and
! with them the generic factory types, from module files.
! GFortran does not accept this LFortran extension.
program traits_generic_factory_03
    use traits_generic_factory_03_traits, only: IClient
    use traits_generic_factory_03_factories, only: make_factory0, make_factory1, &
        make_factory2, client_factory, single_logger_factory
    use traits_generic_factory_03_ifactory, only: IFactory
    use traits_generic_factory_03_types
    use traits_generic_factory_03_container, only: Container
    implicit none
    type(Container) :: cont
    class(IClient), allocatable :: cobj
    class(IFactory), allocatable :: box
    class(*), allocatable :: x

    cont%client = make_factory1(make_client)
    cont%logger = make_factory2(make_double_logger)
    cont%printer = make_factory0(make_printer)
    cont%writer = make_factory0(make_writer)

    cobj = cont%resolve{IClient}()
    if (cobj%level() /= 1034) error stop 1

    ! Switching to single logging changes one registration.
    cont%logger = make_factory1(make_single_logger)
    cobj = cont%resolve{IClient}()
    if (cobj%level() /= 1003) error stop 2

    ! Factories constructed in their own module; `create` dispatches
    ! through the trait object.
    cont%client = client_factory()
    cont%logger = single_logger_factory()
    box = cont%client
    x = box%create(cont)
    select type (x)
    type is (Client)
        if (x%level() /= 1003) error stop 3
    class default
        error stop 4
    end select

    print '(a)', 'traits_generic_factory_03 ok'
end program traits_generic_factory_03
