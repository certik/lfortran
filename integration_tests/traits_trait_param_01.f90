! Trait parameters `{Trait :: P}` (E1): a generic parameter ranging over
! traits. A type-bound generic `resolve` of a sealed, non-generic container
! returns a `class(P), allocatable` trait object, found among objects of
! several concrete types by a `class is (P)` guard; a free generic function
! takes a `class(P)` dummy, queries `class is (P)` and forwards P to another
! generic. Every call is a static instance whose trait argument is explicit.
! The name Trait is not reserved: a variable may take it.
! GFortran does not accept this LFortran extension.
module traits_trait_param_01_m
    implicit none
    private
    public :: IClient, ILogger, IOther, Client, Logger, Plain, Container, &
        any_object, conforms, conforms_twice, kept, keep

    abstract interface :: IClient
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IClient

    abstract interface :: ILogger
        integer function log(self, n)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: n
        end function log
    end interface ILogger

    abstract interface :: IOther
        subroutine other(self)
            type(itself), intent(in), pass :: self
        end subroutine other
    end interface IOther

    type, implements(IClient) :: Client
        integer :: id = 1
    contains
        procedure :: serve => client_serve
    end type Client

    type, implements(ILogger) :: Logger
        integer :: level = 10
    contains
        procedure :: log => logger_log
    end type Logger

    type :: Plain
        integer :: unused = 0
    end type Plain

    type, sealed :: Container
        integer :: client_id = 5
        integer :: logger_level = 20
    contains
        procedure :: resolve
    end type Container

contains

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%id
    end function client_serve

    integer function logger_log(self, n)
        class(Logger), intent(in) :: self
        integer, intent(in) :: n
        logger_log = self%level + n
    end function logger_log

    ! The i-th registered object, of a concrete type.
    function any_object(self, i) result(r)
        type(Container), intent(in) :: self
        integer, intent(in) :: i
        class(*), allocatable :: r
        select case (i)
        case (1)
            r = Plain()
        case (2)
            r = Client(self%client_id)
        case default
            r = Logger(self%logger_level)
        end select
    end function any_object

    ! The first object that conforms to the trait bound to P.
    function resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        integer :: i
        do i = 1, 3
            select type (obj => any_object(self, i))
            type is (Plain)
                if (allocated(res)) error stop "plain after resolve"
            class is (P)
                res = obj
                return
            end select
        end do
        error stop "no registration"
    end function resolve

    logical function conforms{Trait :: P}(object) result(ok)
        class(*), intent(in) :: object
        select type (x => object)
        class is (P)
            ok = .true.
        class default
            ok = .false.
        end select
    end function conforms

    ! A class(P) dummy, and P passed on to another generic.
    logical function conforms_twice{Trait :: P}(view, object) result(ok)
        class(P), intent(in) :: view
        class(*), intent(in) :: object
        ok = conforms{P}(object) .and. kept{P}(view)
    end function conforms_twice

    logical function kept{Trait :: Q}(view) result(ok)
        class(Q), intent(in) :: view
        class(Q), allocatable :: copy
        copy = view
        ok = allocated(copy)
    end function kept

    function keep{Trait :: P}(view) result(copy)
        class(P), intent(in) :: view
        class(P), allocatable :: copy
        copy = view
    end function keep

end module traits_trait_param_01_m

program traits_trait_param_01
    use traits_trait_param_01_m
    implicit none
    integer :: trait = 3
    type(Container) :: cont
    class(IClient), allocatable :: c, c2
    class(ILogger), allocatable :: l
    class(*), allocatable :: object

    cont = Container(client_id=7, logger_level=30)
    c = cont%resolve{IClient}()
    if (c%serve() /= 7) error stop 1
    l = cont%resolve{ILogger}()
    if (l%log(4) /= 34) error stop 2
    ! The same static instance again.
    c2 = cont%resolve{IClient}()
    if (c2%serve() /= 7) error stop 3

    object = Logger(1)
    if (.not. conforms{ILogger}(object)) error stop 4
    if (conforms{IClient}(object)) error stop 5
    if (conforms{IOther}(object)) error stop 6
    object = Client(2)
    if (.not. conforms{IClient}(object)) error stop 7

    if (.not. conforms_twice{IClient}(c, object)) error stop 8
    if (conforms_twice{ILogger}(l, object)) error stop 9

    c2 = keep{IClient}(c)
    if (c2%serve() /= 7) error stop 10

    if (trait /= 3) error stop 11
    trait = trait + 1
    if (trait /= 4) error stop 12
    print '(a)', 'traits_trait_param_01 ok'
end program traits_trait_param_01
