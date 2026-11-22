! A client of the separately compiled modules of
! traits_generic_factory_05_lib: the type-erasing `Factory` of Sect. 4.4 of
! the DI extension, whose generic initializers box generic factory types,
! registered in a container through its generic register0/1/2 and resolved
! through its generic `resolve`, all loaded from module files.
! GFortran does not accept this LFortran extension.
program traits_generic_factory_05
    use traits_generic_factory_05_traits, only: IClient, ILogger, IPrinter, IWriter
    use traits_generic_factory_05_ifactory, only: IFactory
    use traits_generic_factory_05_factory, only: Factory
    use traits_generic_factory_05_types
    use traits_generic_factory_05_container, only: Container
    implicit none
    type(Container) :: cont
    type(Factory) :: f
    class(IClient), allocatable :: cobj
    class(IFactory), allocatable :: box
    class(*), allocatable :: x

    ! Registration inside generic procedures: Factory(ctor) selects the
    ! initializer by the arity of ctor's interface.
    call cont%register{IClient}(make_client)
    call cont%register{ILogger}(make_double_logger)
    call cont%register{IPrinter}(make_printer)
    call cont%register{IWriter}(make_writer)
    if (cont%n /= 4) error stop 1
    cobj = cont%resolve{IClient}()
    if (cobj%level() /= 1034) error stop 2

    ! Switching to single logging changes one registration.
    call cont%register{ILogger}(make_single_logger)
    cobj = cont%resolve{IClient}()
    if (cobj%level() /= 1003) error stop 3

    ! Factory(ctor) at top level, through each initializer.
    f = Factory(make_client)
    x = f%create(cont)
    select type (x)
    type is (Client)
        if (x%level() /= 1003) error stop 4
    class default
        error stop 5
    end select
    f = Factory(make_double_logger)
    box = f
    x = box%create(cont)
    select type (x)
    type is (DoubleLogger)
        if (x%level() /= 34) error stop 6
    class default
        error stop 7
    end select
    f = Factory(make_printer)
    x = f%create(cont)
    select type (x)
    type is (Printer)
        if (x%code /= 3) error stop 8
    class default
        error stop 9
    end select

    print '(a)', 'traits_generic_factory_05 ok'
end program traits_generic_factory_05
