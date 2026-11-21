! Generic derived types with trait parameters (DI extension E1) and
! inference of their parameters from procedure components (E8b): a
! parameter that no actual argument determines, an actual procedure that
! does not match the component's interface, a type argument for a trait
! parameter and a trait argument for a type parameter, and the structure
! constructor of a type with a private procedure component referenced
! outside its module, a conversion of a value of an instance whose type
! arguments are generic parameters to a trait its type does not implement,
! and a binding called on such a value.
module continue_compilation_traits_generic_factory_m
    implicit none
    private
    public :: ILogger, Client, Holder, Pair, Sealed1, make_client, make_wrong, &
        make_logger_client

    abstract interface :: ILogger
        integer function level(self)
            type(itself), intent(in), pass :: self
        end function level
    end interface ILogger

    type :: Client
        integer :: n = 0
    end type Client

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
    end interface

    type :: Holder{Trait :: T1, U}
        procedure(ctor0{U}), pointer, nopass :: ctor => null()
    end type Holder

    type :: Pair{Trait :: T1, U}
        procedure(ctor1{T1, U}), pointer, nopass :: ctor => null()
    end type Pair

    type :: Sealed1{Trait :: T1, U}
        private
        procedure(ctor1{T1, U}), pointer, nopass :: ctor => null()
    end type Sealed1

    type :: Runner{U}
        procedure(ctor0{U}), pointer, nopass :: ctor => null()
    contains
        procedure :: get
    end type Runner

contains

    function get(self) result(y)
        class(Runner{U}), intent(in) :: self
        type(U) :: y
        y = self%ctor()
    end function get

    ! A binding of an instance whose type arguments are the generic's
    ! parameters.
    function run_generic{U}(ctor) result(y)
        procedure(ctor0{U}) :: ctor
        type(U) :: y
        type(Runner{U}) :: r
        r = Runner(ctor)
        y = r%get()
    end function run_generic

    function make_client() result(self)
        type(Client) :: self
    end function make_client

    function make_logger_client(logger) result(self)
        class(ILogger), intent(in) :: logger
        type(Client) :: self
        self%n = logger%level()
    end function make_logger_client

    function to_logger{U}(ctor) result(lg)
        procedure(ctor0{U}) :: ctor
        class(ILogger), allocatable :: lg
        lg = Holder{ILogger, U}(ctor)
    end function to_logger

    function make_wrong(logger) result(self)
        class(ILogger), intent(inout) :: logger
        type(Client) :: self
    end function make_wrong

end module continue_compilation_traits_generic_factory_m

program continue_compilation_traits_generic_factory
    use continue_compilation_traits_generic_factory_m
    implicit none
    type(Holder{ILogger, Client}) :: h
    type(Pair{ILogger, Client}) :: p
    type(Sealed1{ILogger, Client}) :: s
    ! T1 is not determined by the actual procedure.
    h = Holder(make_client)
    ! The actual procedure does not match the component's interface.
    p = Pair(make_wrong)
    ! A type for a trait parameter, and a trait for a type parameter.
    print *, size([Pair{Client, Client}(make_logger_client)])
    print *, size([Pair{ILogger, ILogger}(make_logger_client)])
    ! The component is private outside the module.
    s = Sealed1(make_logger_client)
    s = Sealed1{ILogger, Client}(make_logger_client)
end program continue_compilation_traits_generic_factory
